import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/services/ble/packet_parser.dart';
import 'package:healus/services/database/local_db.dart';
import 'package:healus/services/sync/basal_sync_controller.dart';
import 'package:healus/services/inject/inject_controller.dart';
import 'ble_packet_assembler_test.dart'; // MockBleWriter 사용

/// 테스트용 인메모리 Mock Database 구현체
class MockPumpDatabase implements PumpDatabase {
  final List<PumpLogModel> logs = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> insertLog(PumpLogModel log) async {
    logs.add(log);
  }

  @override
  Future<void> insertLogsBulk(List<PumpLogModel> logsList) async {
    logs.addAll(logsList);
  }

  @override
  Future<List<PumpLogModel>> getAllLogs() async {
    return List.unmodifiable(logs);
  }

  @override
  Future<void> clearLogs() async {
    logs.clear();
  }
}

void main() {
  group('BasalSyncController Tests', () {
    late ProviderContainer container;
    late MockBleWriter mockWriter;
    late MockPumpDatabase mockDb;

    setUp(() {
      mockWriter = MockBleWriter();
      mockDb = MockPumpDatabase();
      container = ProviderContainer(
        overrides: [
          bleWriterProvider.overrideWithValue(mockWriter),
          pumpDatabaseProvider.overrideWithValue(mockDb),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('24시간 기초 설정값을 6개 패킷으로 분할하여 순차 응답 수신에 맞춰 체인 전송한다', () async {
      final syncController = container.read(basalSyncControllerProvider.notifier);

      // 테스트용 24시간 기초 주입량 데이터 (전부 1.25 Unit)
      final basalRates = List<double>.filled(24, 1.25);

      // 동기화 시작 (비동기 루프 구동)
      final syncFuture = syncController.sync24hBasalSettings(basalRates);

      // 첫 번째 패킷(group 1)이 전송 큐를 통해 송신 대기 중이어야 함.
      // 펌프 응답이 오기 전까지는 대기 상태여야 함.
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(basalSyncControllerProvider).isSyncingBasal, true);
      expect(container.read(basalSyncControllerProvider).basalSyncProgress, 0.0);

      // 6번의 정상 응답(RES_OK) 모사 제공
      for (int i = 1; i <= 6; i++) {
        syncController.handleSetResponse(ResCode.ok);
        // 비동기 스케줄링 처리 양보
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 최종 동기화 완료 검증
      final success = await syncFuture;
      expect(success, true);
      expect(container.read(basalSyncControllerProvider).isSyncingBasal, false);
      expect(container.read(basalSyncControllerProvider).basalSyncProgress, 1.0);

      // 전송된 BLE 패킷 건수 검증 (총 6개 패킷 -> 쪼개서 총 12회 전송됨)
      expect(mockWriter.writtenChunks.length, 12);
    });

    test('이력 데이터 수집 요청 시 BT_LOG_REQ 패킷을 전송하고 대량 패킷 스트림을 수신해 DB에 벌크 저장한다', () async {
      final syncController = container.read(basalSyncControllerProvider.notifier);

      // 1. 이력 수집 요청 실행
      syncController.requestHistoryLogs();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockWriter.writtenChunks.length, 2); // BT_LOG_REQ 10Byte*2회 전송 완료

      // 2. 펌프 측 대량 데이터 송신 시작 알림 수신 모사 (BT_DATA_START_IND)
      final startPacket = List<int>.filled(20, 0);
      startPacket[0] = kStartCode;
      startPacket[1] = Opcodes.btDataStartInd;
      startPacket[2] = 0;

      await syncController.handleIncomingPacket(startPacket);
      expect(container.read(basalSyncControllerProvider).isSyncingLogs, true);

      // 3. 14Byte 이력 응답 데이터 패킷 1개 수신 모사
      // 5월 26일, 기초총량 12.5 Unit(1250), 식사총량 8.0 Unit(800), 아침 2.5(250), 점심 3.0(300), 저녁 2.5(250), 추가 1.5(150)
      final logPacket = List<int>.filled(20, 0);
      logPacket[0] = kStartCode;
      logPacket[1] = 0xAA; // 임의의 대량 데이터 Opcode
      logPacket[2] = 14; // 데이터 길이 14 (이력 데이터)
      logPacket[3] = 0x05; // 5월
      logPacket[4] = 0x1A; // 26일
      
      // 2바이트씩 Little-endian 적재
      PacketParser.writeUint16(logPacket, 5, 1250);
      PacketParser.writeUint16(logPacket, 7, 800);
      PacketParser.writeUint16(logPacket, 9, 250);
      PacketParser.writeUint16(logPacket, 11, 300);
      PacketParser.writeUint16(logPacket, 13, 250);
      PacketParser.writeUint16(logPacket, 15, 150);

      await syncController.handleIncomingPacket(logPacket);

      // 4. 대량 데이터 전송 완료 알림 수신 모사 (BT_DATA_END_IND)
      final endPacket = List<int>.filled(20, 0);
      endPacket[0] = kStartCode;
      endPacket[1] = Opcodes.btDataEndInd;
      endPacket[2] = 0;

      await syncController.handleIncomingPacket(endPacket);

      // 이력 수집이 종료되었고, 상태 로그 목록에 반영되었는지 확인
      final state = container.read(basalSyncControllerProvider);
      expect(state.isSyncingLogs, false);
      expect(state.logs.length, 1);

      final savedLog = state.logs[0];
      expect(savedLog.month, 5);
      expect(savedLog.day, 26);
      expect(savedLog.baseTotal, 12.5);
      expect(savedLog.eatTotal, 8.0);
      expect(savedLog.morningTotal, 2.5);
      expect(savedLog.afternoonTotal, 3.0);
      expect(savedLog.eveningTotal, 2.5);
      expect(savedLog.appendTotal, 1.5);

      // Mock 데이터베이스에도 실제로 잘 적재되었는지 검증
      final dbLogs = await mockDb.getAllLogs();
      expect(dbLogs.length, 1);
      expect(dbLogs[0].baseTotal, 12.5);
    });
  });
}
