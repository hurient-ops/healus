import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/opcodes.dart';
import '../ble/packet_parser.dart';
import '../inject/inject_controller.dart';
import '../database/local_db.dart';
import '../../globals.dart';
import 'package:flutter/material.dart';

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

  /// 실제 패킷을 통해 로그 데이터(이력)가 성공적으로 동기화되었는지 여부
  final bool hasReceivedRealLogs;

  BasalSyncState({
    this.isSyncingBasal = false,
    this.basalSyncProgress = 0.0,
    this.isSyncingLogs = false,
    this.logs = const [],
    this.hasReceivedRealLogs = false,
  });

  BasalSyncState copyWith({
    bool? isSyncingBasal,
    double? basalSyncProgress,
    bool? isSyncingLogs,
    List<PumpLogModel>? logs,
    bool? hasReceivedRealLogs,
  }) {
    return BasalSyncState(
      isSyncingBasal: isSyncingBasal ?? this.isSyncingBasal,
      basalSyncProgress: basalSyncProgress ?? this.basalSyncProgress,
      isSyncingLogs: isSyncingLogs ?? this.isSyncingLogs,
      logs: logs ?? this.logs,
      hasReceivedRealLogs: hasReceivedRealLogs ?? this.hasReceivedRealLogs,
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

  final List<PumpLogModel> _tempLogs = [];

  Timer? _watchdogTimer;

  /// 벌크 전송 무한 로딩 방지를 위한 워치독 타이머 (3초)
  void _startOrResetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 3), () {
      if (state.isSyncingLogs) {
        state = state.copyWith(isSyncingLogs: false);
        _tempLogs.clear();
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('통신 지연으로 동기화가 중단되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
        print("[DEBUG] basal_sync_controller: 3초 타임아웃! 대량 전송 강제 종료");
      }
    });
  }

  void _cancelWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

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

        // 2. 패킷 전송 큐 인입 (InjectController가 BleMutex로 1:1 전송 보장)
        _ref.read(injectControllerProvider.notifier).queuePacket(packet);

        // 진행률 업데이트 (큐 적재 기준이므로 사실상 거의 즉시 1.0 도달, 실제 처리는 백그라운드 큐가 담당)
        state = state.copyWith(basalSyncProgress: group / 6.0);
      }

      state = state.copyWith(isSyncingBasal: false, basalSyncProgress: 1.0);
      return true;
    } catch (e) {
      print("기초 주입량 동기화 큐 적재 실패: $e");
      state = state.copyWith(isSyncingBasal: false);
      return false;
    }
  }

  /// 펌프로부터 설정 완료 응답(Ack)을 수신했을 때 호출되어 동기화 체인의 잠금을 해제합니다.
  /// (더 이상 사용되지 않지만 기존 호환성을 위해 빈 함수로 남겨둠)
  void handleSetResponse(ResCode resCode) {
    // BleMutex 도입으로 인해 개별 컨트롤러에서 대기할 필요 없음.
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
  Future<void> handleIncomingPacket(List<int> packet, {bool isRealPacket = false}) async {
    if (packet.length != 20) {
      return;
    }

    // 이력 데이터 동기화 모드이고, 대량 패킷 수집 중일 때는 시작 코드 검사를 건너뜀 (문서상 헤더가 없음)
    if (state.isSyncingLogs && packet[0] != kStartCode) {
      // 0번째부터 데이터 파싱
      final int month = packet[0];
      final int day = packet[1];
      final double base = PacketParser.readUint16(packet, 2) / 100.0;
      final double eat = PacketParser.readUint16(packet, 4) / 100.0;
      final double morning = PacketParser.readUint16(packet, 6) / 100.0;
      final double afternoon = PacketParser.readUint16(packet, 8) / 100.0;
      final double evening = PacketParser.readUint16(packet, 10) / 100.0;
      final double append = PacketParser.readUint16(packet, 12) / 100.0;

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

      print("[DEBUG] basal_sync_controller: collected log for month=$month, day=$day");
      _tempLogs.add(log);
      return;
    }

    // 일반 패킷(헤더 존재)
    if (packet[0] != kStartCode) {
      return;
    }

    final int opCode = packet[1];
    final int dataLen = packet[2];

    switch (opCode) {
      case Opcodes.btLogInjQntInd:
        if (dataLen >= 13) {
          final double base = PacketParser.readUint16(packet, 6) / 100.0;
          final double morning = PacketParser.readUint16(packet, 8) / 100.0;
          final double lunch = PacketParser.readUint16(packet, 10) / 100.0;
          final double evening = PacketParser.readUint16(packet, 12) / 100.0;
          final double append = PacketParser.readUint16(packet, 14) / 100.0;
          
          if (state.hasReceivedRealLogs && !isRealPacket) {
            print("[DEBUG] basal_sync_controller: hasReceivedRealLogs is true. Ignoring mock summary log packet.");
            break;
          }

          final now = DateTime.now();
          final log = PumpLogModel(
            month: now.month,
            day: now.day,
            baseTotal: base,
            eatTotal: morning + lunch + evening,
            morningTotal: morning,
            afternoonTotal: lunch,
            eveningTotal: evening,
            appendTotal: append,
            createdAt: now.toIso8601String(),
          );
          
          print("[DEBUG] basal_sync_controller: btLogInjQntInd received. Saving today's summary to DB.");
          await _db.insertLog(log);
          await _db.keepOnlyLast180Days();
          await reloadLogsFromDb();

          if (isRealPacket) {
            state = state.copyWith(hasReceivedRealLogs: true);
          }
        }
        break;

      case Opcodes.btDataStartInd:
        print("[DEBUG] basal_sync_controller: btDataStartInd received");
        
        if (state.hasReceivedRealLogs && !isRealPacket) {
          print("[DEBUG] basal_sync_controller: hasReceivedRealLogs is true. Ignoring mock log start packet.");
          break;
        }

        // 이력 대량 전송 시작 알림 수신
        _tempLogs.clear();
        state = state.copyWith(
          isSyncingLogs: true,
          hasReceivedRealLogs: isRealPacket ? true : state.hasReceivedRealLogs,
        );
        _startOrResetWatchdog();
        break;

      case Opcodes.btDataEndInd:
        print("[DEBUG] basal_sync_controller: btDataEndInd received, isSyncingLogs=${state.isSyncingLogs}, tempLogsCount=${_tempLogs.length}");
        // 이력 대량 전송 종료 알림 수신 -> 로컬 DB에 벌크 인서트 후 화면 데이터 로드
        if (state.isSyncingLogs) {
          _cancelWatchdog();
          await _db.insertLogsBulk(_tempLogs);
          await _db.keepOnlyLast180Days();
          print("[DEBUG] basal_sync_controller: insertLogsBulk completed");
          _tempLogs.clear();
          await reloadLogsFromDb();
          state = state.copyWith(
            isSyncingLogs: false,
          );
        }
        break;

      case Opcodes.btLogDataInd:
        if (state.isSyncingLogs && dataLen == 14) {
          _startOrResetWatchdog();
          
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

      default:
        break;
    }
  }

  /// DB로부터 이력 데이터 리스트를 강제로 다시 로드
  Future<void> reloadLogsFromDb() async {
    final allLogs = await _db.getAllLogs();
    
    // 오늘 기준 최근 180일간의 날짜 리스트를 생성하고 빈 날짜는 0으로 채움
    final List<PumpLogModel> filledLogs = [];
    final now = DateTime.now();
    for (int i = 179; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final m = targetDate.month;
      final d = targetDate.day;

      final match = allLogs.firstWhere(
        (log) => log.month == m && log.day == d,
        orElse: () => PumpLogModel(
          month: m,
          day: d,
          baseTotal: 0.0,
          eatTotal: 0.0,
          morningTotal: 0.0,
          afternoonTotal: 0.0,
          eveningTotal: 0.0,
          appendTotal: 0.0,
          createdAt: targetDate.toIso8601String(),
        ),
      );
      filledLogs.add(match);
    }
    
    state = state.copyWith(logs: filledLogs);
  }
}

/// 전역 동기화 컨트롤러 프로바이더
final basalSyncControllerProvider =
    StateNotifierProvider<BasalSyncController, BasalSyncState>((ref) {
  final db = ref.read(pumpDatabaseProvider);
  return BasalSyncController(ref, db);
});
