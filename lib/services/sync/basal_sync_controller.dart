import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/opcodes.dart';
import '../ble/packet_parser.dart';
import '../inject/inject_controller.dart';
import '../database/local_db.dart';

/// 24시간 기초 설정 및 이력 데이터 동기화 상태 모델
class BasalSyncState {
  /// 24시간 기초 설정 동기화 진행 여부
  final bool isSyncingBasal;

  /// 기초 설정 동기화 진행률 (0.0 ~ 1.0)
  final double basalSyncProgress;

  /// 이력 데이터 수집 진행 여부
  final bool isSyncingLogs;

  /// DB에 영구 저장된 이력 데이터 리스트 (차트 갱신용)
  final List<PumpLogModel> logs;

  BasalSyncState({
    this.isSyncingBasal = false,
    this.basalSyncProgress = 0.0,
    this.isSyncingLogs = false,
    this.logs = const [],
  });

  BasalSyncState copyWith({
    bool? isSyncingBasal,
    double? basalSyncProgress,
    bool? isSyncingLogs,
    List<PumpLogModel>? logs,
  }) {
    return BasalSyncState(
      isSyncingBasal: isSyncingBasal ?? this.isSyncingBasal,
      basalSyncProgress: basalSyncProgress ?? this.basalSyncProgress,
      isSyncingLogs: isSyncingLogs ?? this.isSyncingLogs,
      logs: logs ?? this.logs,
    );
  }
}

/// 데이터베이스 접근 프로바이더 (단위 테스트 시 Mock 주입 가능하도록 설계)
final pumpDatabaseProvider = Provider<PumpDatabase>((ref) {
  throw UnimplementedError("pumpDatabaseProvider가 재정의(override)되지 않았습니다.");
});

/// 기초 설정 대량 동기화 및 펌프 로그 수집 파이프라인 컨트롤러
class BasalSyncController extends StateNotifier<BasalSyncState> {
  final Ref _ref;
  final PumpDatabase _db;

  Completer<ResCode>? _basalAckCompleter;
  final List<PumpLogModel> _tempLogs = [];

  BasalSyncController(this._ref, this._db) : super(BasalSyncState());

  /// 24시간 치 기초 주입 설정을 6개의 독립 패킷(8Byte*6개)으로 쪼개서 연쇄 송신합니다.
  /// 각 단계마다 펌프로부터 정상 응답(RES_OK)을 확인하면 체인 방식으로 다음 송신을 실행합니다.
  /// [basalRates]: 24시간 치 주입량 리스트 (길이 24)
  Future<bool> sync24hBasalSettings(List<double> basalRates) async {
    if (basalRates.length != 24) {
      throw ArgumentError("기초 설정 데이터는 24개(24시간) 기준이어야 합니다.");
    }

    state = state.copyWith(isSyncingBasal: true, basalSyncProgress: 0.0);

    try {
      for (int group = 1; group <= 6; group++) {
        _basalAckCompleter = Completer<ResCode>();

        // 1. 패킷 구성
        final packet = List<int>.filled(20, 0);
        packet[0] = kStartCode;
        packet[1] = Opcodes.btTimeBaseSetReq;
        packet[2] = 9; // Data length (time_param 1B + set_hour 8B)
        packet[3] = group; // time_param (1 ~ 6)

        // 4시간 분량(각 2Byte Little-endian) 직렬화
        final int startIndex = (group - 1) * 4;
        for (int i = 0; i < 4; i++) {
          final double rate = basalRates[startIndex + i];
          final int scaledVal = (rate * 100).round();
          PacketParser.writeUint16(packet, 4 + (i * 2), scaledVal);
        }

        // 2. 패킷 전송 큐 인입
        _ref.read(injectControllerProvider.notifier).queuePacket(packet);

        // 3. 기기로부터 Ack (BT_SET_RES 등) 수신 대기 (최대 5초 타임아웃 방어)
        final resCode = await _basalAckCompleter!.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException("기기 응답 제한 시간(5초)을 초과하였습니다.");
          },
        );

        if (resCode != ResCode.ok) {
          state = state.copyWith(isSyncingBasal: false);
          return false;
        }

        // 진행률 업데이트
        state = state.copyWith(basalSyncProgress: group / 6.0);
      }

      state = state.copyWith(isSyncingBasal: false, basalSyncProgress: 1.0);
      return true;
    } catch (e) {
      print("기초 주입량 동기화 체인 진행 실패: $e");
      state = state.copyWith(isSyncingBasal: false);
      return false;
    } finally {
      _basalAckCompleter = null;
    }
  }

  /// 펌프로부터 설정 완료 응답(Ack)을 수신했을 때 호출되어 동기화 체인의 잠금을 해제합니다.
  void handleSetResponse(ResCode resCode) {
    if (_basalAckCompleter != null && !_basalAckCompleter!.isCompleted) {
      _basalAckCompleter!.complete(resCode);
    }
  }

  /// 이력 데이터 요청 (BT_LOG_REQ, 0x1D)
  void requestHistoryLogs() {
    final packet = List<int>.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btLogReq;
    packet[2] = 0; // Data length

    _ref.read(injectControllerProvider.notifier).queuePacket(packet);
  }

  /// BLE 패킷 리스너로부터 들어오는 대량 패킷(이력 데이터 등) 수집 처리 파이프라인
  Future<void> handleIncomingPacket(List<int> packet) async {
    if (packet.length != 20 || packet[0] != kStartCode) {
      return;
    }

    final int opCode = packet[1];
    final int dataLen = packet[2];

    switch (opCode) {
      case Opcodes.btDataStartInd:
        // 이력 대량 전송 시작 알림 수신
        _tempLogs.clear();
        state = state.copyWith(isSyncingLogs: true);
        break;

      case Opcodes.btDataEndInd:
        // 이력 대량 전송 종료 알림 수신 -> 로컬 DB에 벌크 인서트 후 화면 데이터 로드
        if (state.isSyncingLogs) {
          await _db.insertLogsBulk(_tempLogs);
          _tempLogs.clear();
          final allLogs = await _db.getAllLogs();
          state = state.copyWith(
            isSyncingLogs: false,
            logs: allLogs,
          );
        }
        break;

      default:
        // 이력 데이터 수집 모드인 경우 14Byte 이력 응답 데이터 파싱
        if (state.isSyncingLogs && dataLen == 14) {
          final int month = packet[3];
          final int day = packet[4];

          // 2Byte Little-endian으로 정수 인코딩되어 인입되므로, 스케일링 팩 100을 복원
          final double base = PacketParser.readUint16(packet, 5) / 100.0;
          final double eat = PacketParser.readUint16(packet, 7) / 100.0;
          final double morning = PacketParser.readUint16(packet, 9) / 100.0;
          final double afternoon = PacketParser.readUint16(packet, 11) / 100.0;
          final double evening = PacketParser.readUint16(packet, 13) / 100.0;
          final double append = PacketParser.readUint16(packet, 15) / 100.0;

          final log = PumpLogModel(
            month: month,
            day: day,
            baseTotal: base,
            eatTotal: eat,
            morningTotal: morning,
            afternoonTotal: afternoon,
            eveningTotal: evening,
            appendTotal: append,
            createdAt: DateTime.now().toIso8601String(),
          );

          _tempLogs.add(log);
        }
        break;
    }
  }

  /// DB로부터 이력 데이터 리스트를 강제로 다시 로드
  Future<void> reloadLogsFromDb() async {
    final allLogs = await _db.getAllLogs();
    state = state.copyWith(logs: allLogs);
  }
}

/// 전역 동기화 컨트롤러 프로바이더
final basalSyncControllerProvider =
    StateNotifierProvider<BasalSyncController, BasalSyncState>((ref) {
  final db = ref.read(pumpDatabaseProvider);
  return BasalSyncController(ref, db);
});
