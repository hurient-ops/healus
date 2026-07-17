import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/services/ble/packet_parser.dart';
import 'package:healus/services/ble/ble_service_interface.dart';
import 'package:healus/services/ble/ble_service_provider.dart';
import 'package:healus/services/database/local_db.dart';
import 'package:healus/services/database/local_db.dart';
import 'package:healus/services/sync/basal_sync_controller.dart';

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
  Future<int> keepOnlyLast180Days() async { return 0; }


  @override
  Future<List<PumpLogModel>> getAllLogs() async {
    return List.unmodifiable(logs);
  }

  @override
  Future<void> clearLogs() async {
    logs.clear();
  }

  Future<void> keepOnlyLast15Days() async {}
}

/// 단위 테스트를 위한 Test BLE Service
class TestBleService implements BleService {
  @override
  void Function(List<int>)? onPacketSent;

  final List<List<int>> writtenPackets = [];
  bool _connected = true;

  @override
  Stream<bool> get connectionStateStream => Stream.value(_connected);

  @override
  Stream<List<int>> get receivedPacketsStream => const Stream.empty();

  @override
  bool get isConnected => _connected;

  @override
  bool get isTestMode => false;

  @override
  Future<void> connect(String macAddress) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> sendPacket(List<int> packet) async {
    writtenPackets.add(packet);
    onPacketSent?.call(packet);
  }

  @override
  void setTestMode(bool testMode) {}

  @override
  void setBypassTimeoutHold(bool hold) {}

  @override
  Future<void> setPauseState(bool pause) async {
    final List<int> packet = List.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btStopCtrlReq;
    packet[2] = 1;
    packet[3] = pause ? 1 : 0;
    await sendPacket(packet);
  }

  @override
  Future<void> resetDevice() async {
    final List<int> packet = List.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btSystemReset;
    packet[2] = 0;
    await sendPacket(packet);
    await disconnect();
  }
}

void main() {
  group('BasalSyncController Tests', () {
    late ProviderContainer container;
    late TestBleService testBleService;
    late MockPumpDatabase mockDb;

    setUp(() {
      testBleService = TestBleService();
      mockDb = MockPumpDatabase();
      container = ProviderContainer(
        overrides: [
          bleServiceProvider.overrideWithValue(testBleService),
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

      // 전송된 BLE 패킷 건수 검증 (총 6개 패킷)
      expect(testBleService.writtenPackets.length, 6);
    });

    test('이력 데이터 수집 요청 시 BT_LOG_REQ 패킷을 전송하고 대량 패킷 스트림을 수신해 DB에 벌크 저장한다', () async {
      final syncController = container.read(basalSyncControllerProvider.notifier);

      // 1. 이력 수집 요청 실행
      syncController.requestHistoryLogs();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(testBleService.writtenPackets.length, 1); // BT_LOG_REQ 20Byte 패킷 1회 전송 완료

      // 2. 펌프 측 대량 데이터 송신 시작 알림 수신 모사 (BT_DATA_START_IND)
      final startPacket = List<int>.filled(20, 0);
      startPacket[0] = kStartCode;
      startPacket[1] = Opcodes.btDataStartInd;
      startPacket[2] = 0;

      await syncController.handleIncomingPacket(startPacket);
      expect(container.read(basalSyncControllerProvider).isSyncingLogs, true);

      // 3. 헤더가 없는 이력 응답 데이터 패킷 1개 수신 모사 (월/일 기준 14Byte)
      final now = DateTime.now();
      final logPacket = List<int>.filled(20, 0);
      logPacket[0] = now.month;
      logPacket[1] = now.day;
      
      // 2바이트씩 Little-endian 적재 (0번째 기준 오프셋 2, 4, 6...)
      PacketParser.writeUint16(logPacket, 2, 1250);
      PacketParser.writeUint16(logPacket, 4, 800);
      PacketParser.writeUint16(logPacket, 6, 250);
      PacketParser.writeUint16(logPacket, 8, 300);
      PacketParser.writeUint16(logPacket, 10, 250);
      PacketParser.writeUint16(logPacket, 12, 150);

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
      expect(state.logs.length, 15);

      final currentNow = DateTime.now();
      final savedLog = state.logs.firstWhere((log) => log.month == currentNow.month && log.day == currentNow.day);
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
