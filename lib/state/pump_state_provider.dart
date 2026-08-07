import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble/opcodes.dart';
import '../services/ble/packet_parser.dart';
import '../services/api/cloud_sync_service.dart';
import '../services/database/sync_queue_db.dart';
import '../services/api/api_client.dart';

/// HealUs 펌프의 전역 상태 모델
class PumpStateData {
  /// 현재 펌프 기기 상태 (대기, 주입중, 오류정지 등)
  final PumpState connectionState;

  /// 인슐린 주입 중 여부 (UI Lock 트리거 대상)
  final bool isPumpInjecting;

  /// 운동 감량 모드 활성화 상태
  final bool isExerciseActive;

  /// 배터리 잔량 레벨 (0: Empty ~ 4: Full)
  final int batteryLevel;

  /// 인슐린 잔량 (Unit 단위, 소수점 포함)
  final double insulinRemaining;

  /// 디바이스 인증용 비밀번호 (기본값: '000000')
  final String password;

  /// 인슐린펌프 고유 식별자 PID
  final String pumpPid;

  /// 인슐린펌프 펌웨어 버전
  final String firmwareVersion;

  /// 오늘 누적 기초 주입량
  final double basalSum;

  /// 오늘 누적 식사 주입량
  final double mealSum;

  /// 오늘 누적 추가 주입량
  final double appendSum;

  /// 아침/점심/저녁 설정 주입량 맵
  final Map<String, double> mealSettings;

  /// 24시간 시간대별 기초 주입 속도 리스트 (길이 24)
  final List<double> basalRates;

  /// 실제 하드웨어 기기 배터리 패킷 수신 여부
  final bool hasReceivedBattery;

  /// 실제 하드웨어 기기 인슐린 패킷 수신 여부
  final bool hasReceivedInsulin;

  /// 실제 하드웨어 기기 금일 주입량 패킷 수신 여부
  final bool hasReceivedSummary;

  /// 실제 기기 비밀번호 갱신 완료 여부
  final bool isPasswordProvisioned;

  /// 실제 패킷(수동 주입 포함)을 통해 누적 주입량이 업데이트되었는지 여부
  final bool hasReceivedRealSummary;

  /// 실제 패킷을 통해 배터리가 업데이트되었는지 여부
  final bool hasReceivedRealBattery;

  /// 실제 패킷을 통해 인슐린 잔량이 업데이트되었는지 여부
  final bool hasReceivedRealInsulin;

  /// 실제 패킷을 통해 식사설정이 업데이트되었는지 여부
  final bool hasReceivedRealMeal;

  /// 실제 패킷을 통해 펌웨어 버전이 업데이트되었는지 여부
  final bool hasReceivedRealFirmware;

  /// 실제 패킷을 통해 기초 설정값이 업데이트되었는지 여부
  final bool hasReceivedRealBasal;

  PumpStateData({
    this.connectionState = PumpState.idle,
    this.isPumpInjecting = false,
    this.isExerciseActive = false,
    this.batteryLevel = 4,
    this.insulinRemaining = 300.0,
    this.password = "000000",
    this.pumpPid = "",
    this.firmwareVersion = "v1.0",
    this.basalSum = 0.0,
    this.mealSum = 0.0,
    this.appendSum = 0.0,
    this.mealSettings = const {
      'breakfast': 1.00,
      'lunch': 1.00,
      'dinner': 1.00,
    },
    this.basalRates = const [],
    this.hasReceivedBattery = false,
    this.hasReceivedInsulin = false,
    this.hasReceivedSummary = false,
    this.isPasswordProvisioned = false,
    this.hasReceivedRealSummary = false,
    this.hasReceivedRealBattery = false,
    this.hasReceivedRealInsulin = false,
    this.hasReceivedRealMeal = false,
    this.hasReceivedRealFirmware = false,
    this.hasReceivedRealBasal = false,
  });

  PumpStateData copyWith({
    PumpState? connectionState,
    bool? isPumpInjecting,
    bool? isExerciseActive,
    int? batteryLevel,
    double? insulinRemaining,
    String? password,
    String? pumpPid,
    String? firmwareVersion,
    double? basalSum,
    double? mealSum,
    double? appendSum,
    Map<String, double>? mealSettings,
    List<double>? basalRates,
    bool? hasReceivedBattery,
    bool? hasReceivedInsulin,
    bool? hasReceivedSummary,
    bool? isPasswordProvisioned,
    bool? hasReceivedRealSummary,
    bool? hasReceivedRealBattery,
    bool? hasReceivedRealInsulin,
    bool? hasReceivedRealMeal,
    bool? hasReceivedRealFirmware,
    bool? hasReceivedRealBasal,
  }) {
    return PumpStateData(
      connectionState: connectionState ?? this.connectionState,
      isPumpInjecting: isPumpInjecting ?? this.isPumpInjecting,
      isExerciseActive: isExerciseActive ?? this.isExerciseActive,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      insulinRemaining: insulinRemaining ?? this.insulinRemaining,
      password: password ?? this.password,
      pumpPid: pumpPid ?? this.pumpPid,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      basalSum: basalSum ?? this.basalSum,
      mealSum: mealSum ?? this.mealSum,
      appendSum: appendSum ?? this.appendSum,
      mealSettings: mealSettings ?? this.mealSettings,
      basalRates: basalRates ?? this.basalRates,
      hasReceivedBattery: hasReceivedBattery ?? this.hasReceivedBattery,
      hasReceivedInsulin: hasReceivedInsulin ?? this.hasReceivedInsulin,
      hasReceivedSummary: hasReceivedSummary ?? this.hasReceivedSummary,
      isPasswordProvisioned: isPasswordProvisioned ?? this.isPasswordProvisioned,
      hasReceivedRealSummary: hasReceivedRealSummary ?? this.hasReceivedRealSummary,
      hasReceivedRealBattery: hasReceivedRealBattery ?? this.hasReceivedRealBattery,
      hasReceivedRealInsulin: hasReceivedRealInsulin ?? this.hasReceivedRealInsulin,
      hasReceivedRealMeal: hasReceivedRealMeal ?? this.hasReceivedRealMeal,
      hasReceivedRealFirmware: hasReceivedRealFirmware ?? this.hasReceivedRealFirmware,
      hasReceivedRealBasal: hasReceivedRealBasal ?? this.hasReceivedRealBasal,
    );
  }
}

/// 펌프의 상태 관리를 수행하는 StateNotifier
class PumpStateNotifier extends StateNotifier<PumpStateData> {
  PumpStateNotifier() : super(PumpStateData(basalRates: List.filled(24, 0.0)));

  /// 블루투스 연결이 비정상적으로 끊어졌을 때 호출되어 UI를 대기 상태로 강제 복구합니다.
  void resetInjectingState() {
    print("[DEBUG] PumpStateNotifier: 연결 단절로 인한 UI 강제 초기화 (대기 상태 전환)");
    state = state.copyWith(
      connectionState: PumpState.idle,
      isPumpInjecting: false,
    );
  }

  void _syncPumpStatusToCloud(PumpStateData newState) {
    final pumpPid = CloudSyncService().currentPumpPid ?? 'UNKNOWN_PID';
    ApiClient().postPumpStatus(newState.batteryLevel, newState.insulinRemaining, pumpPid);
  }

  /// 20Byte BLE 논리 패킷을 입력받아 전역 상태를 업데이트합니다.
  void handleIncomingPacket(List<int> packet, {bool isRealPacket = false}) {
    if (packet.length != 20 || packet[0] != kStartCode) {
      return;
    }

    final int opCode = packet[1];
    final int dataLen = packet[2];

    switch (opCode) {
      case Opcodes.btStateInd:
        if (dataLen >= 1) {
          final stateVal = packet[3];
          final pumpState = PumpState.fromValue(stateVal);
          state = state.copyWith(
            connectionState: pumpState,
            isPumpInjecting: pumpState == PumpState.injecting,
          );
        }
        break;

      case Opcodes.btBattDataInd:
      case Opcodes.btBattDataRes:
        if (dataLen >= 1) {
          final level = packet[3];
          if (state.hasReceivedRealBattery && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealBattery is true. Ignoring mock battery packet.");
            break;
          }
          state = state.copyWith(
            batteryLevel: level.clamp(0, 4),
            hasReceivedBattery: true,
            hasReceivedRealBattery: isRealPacket ? true : state.hasReceivedRealBattery,
          );
          _syncPumpStatusToCloud(state);
        }
        break;

      case Opcodes.btSetRes:
        // BT_SET_RES: [3..8] set_date (6B), [9..10] insul_remain (2B) -> offset 9
        if (dataLen >= 8) {
          final insulRaw = PacketParser.readUint16(packet, 9);
          if (state.hasReceivedRealInsulin && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealInsulin is true. Ignoring mock insulin packet (btSetRes).");
            break;
          }
          state = state.copyWith(
            insulinRemaining: insulRaw / 100.0,
            hasReceivedInsulin: true,
            hasReceivedRealInsulin: isRealPacket ? true : state.hasReceivedRealInsulin,
          );
          _syncPumpStatusToCloud(state);
        }
        break;

      case Opcodes.btInjInfoRes:
        // BT_INJ_INFO_RES: [3] inj_info, [4..9] set_date (6B), [10..11] insul_set, [12..13] insul_remain -> offset 12
        if (dataLen >= 11) {
          final insulRaw = PacketParser.readUint16(packet, 12);
          if (state.hasReceivedRealInsulin && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealInsulin is true. Ignoring mock insulin packet (btInjInfoRes).");
            break;
          }
          state = state.copyWith(
            insulinRemaining: insulRaw / 100.0,
            hasReceivedInsulin: true,
            hasReceivedRealInsulin: isRealPacket ? true : state.hasReceivedRealInsulin,
          );
          _syncPumpStatusToCloud(state);
        }
        break;

      case Opcodes.btInjStartInd:
      case Opcodes.btReceptionInjStartInd:
        // 주입 시작 시 UI Lock 오버레이 트리거
        state = state.copyWith(
          isPumpInjecting: true,
          connectionState: PumpState.injecting,
        );
        break;

      case Opcodes.btExerciseInjStartInd:
        // 운동 감량 모드 시작 시 (주입 잠금 안 함)
        state = state.copyWith(
          isExerciseActive: true,
        );
        break;

      case Opcodes.btInjStopInd:
      case Opcodes.btReceptionInjStopInd:
        // 주입 완료 시 UI Lock 오버레이 해제 및 잔량 갱신 (마지막 2B insul_remain -> offset 12)
        double currentRemain = state.insulinRemaining;
        if (dataLen >= 11) {
          final insulRaw = PacketParser.readUint16(packet, 12);
          currentRemain = insulRaw / 100.0;
        }
        if (state.hasReceivedRealInsulin && !isRealPacket) {
          print("[DEBUG] PumpStateNotifier: hasReceivedRealInsulin is true. Restoring lock state only and ignoring mock insulin remaining.");
          state = state.copyWith(
            isPumpInjecting: false,
            connectionState: PumpState.idle,
          );
          break;
        }
        state = state.copyWith(
          isPumpInjecting: false,
          connectionState: PumpState.idle,
          insulinRemaining: currentRemain,
          hasReceivedInsulin: true,
          hasReceivedRealInsulin: isRealPacket ? true : state.hasReceivedRealInsulin,
        );
        _syncPumpStatusToCloud(state);
        break;

      case Opcodes.btExerciseInjStopInd:
        state = state.copyWith(
          isExerciseActive: false,
        );
        break;

      case Opcodes.btErrInd:
        // 오류 상태 발생 시 안전상 주입 락 상태는 해제하고, 기기는 오류 정지 상태로 전이
        state = state.copyWith(
          connectionState: PumpState.errorPause,
          isPumpInjecting: false,
        );
        break;

      case Opcodes.btEatValueRes:
        // 식사 설정값 응답: [3..4] 아침, [5..6] 점심, [7..8] 저녁 (각 2B Scale x100)
        if (dataLen >= 6) {
          final bf = PacketParser.readUint16(packet, 3) / 100.0;
          final ln = PacketParser.readUint16(packet, 5) / 100.0;
          final dn = PacketParser.readUint16(packet, 7) / 100.0;
          if (state.hasReceivedRealMeal && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealMeal is true. Ignoring mock meal settings packet.");
            break;
          }
          state = state.copyWith(
            mealSettings: {
              'breakfast': bf,
              'lunch': ln,
              'dinner': dn,
            },
            hasReceivedRealMeal: isRealPacket ? true : state.hasReceivedRealMeal,
          );
        }
        break;

      case Opcodes.btBaseValueRes:
      case Opcodes.btBaseValueInd:
        // 기초 설정값 응답/알림: [3] time_param (1..3), [4..19] 8구간 기초값 (각 2B)
        if (dataLen >= 17) {
          final int group = packet[3];
          if (state.hasReceivedRealBasal && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealBasal is true. Ignoring mock basal packet.");
            break;
          }
          final List<double> newRates = List.from(state.basalRates);
          final int startHour = (group - 1) * 8;
          for (int hour = 0; hour < 8; hour++) {
            if (startHour + hour < 24) {
              final rawRate = PacketParser.readUint16(packet, 4 + (hour * 2));
              newRates[startHour + hour] = rawRate / 100.0;
            }
          }
          state = state.copyWith(
            basalRates: newRates,
            hasReceivedRealBasal: isRealPacket ? true : state.hasReceivedRealBasal,
          );
        }
        break;

      case Opcodes.btLogInjSet1Ind:
        // 식사 설정 변경 알림: [3] hour, [4] min, [5] sec, [6..7] breakfast, [8..9] lunch, [10..11] dinner
        if (dataLen >= 9) {
          final bf = PacketParser.readUint16(packet, 6) / 100.0;
          final ln = PacketParser.readUint16(packet, 8) / 100.0;
          final dn = PacketParser.readUint16(packet, 10) / 100.0;
          if (state.hasReceivedRealMeal && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealMeal is true. Ignoring mock meal change packet.");
            break;
          }
          state = state.copyWith(
            mealSettings: {
              'breakfast': bf,
              'lunch': ln,
              'dinner': dn,
            },
            hasReceivedRealMeal: isRealPacket ? true : state.hasReceivedRealMeal,
          );
        }
        break;

      case Opcodes.btLogInjQntInd:
        // 금일 누적 주입량 알림: [3..5] 시간(H/M/S), [6..7] 기초, [8..9] 아침, [10..11] 점심, [12..13] 저녁, [14..15] 추가
        if (dataLen >= 13) {
          final double base = PacketParser.readUint16(packet, 6) / 100.0;
          final double morning = PacketParser.readUint16(packet, 8) / 100.0;
          final double lunch = PacketParser.readUint16(packet, 10) / 100.0;
          final double evening = PacketParser.readUint16(packet, 12) / 100.0;
          final double append = PacketParser.readUint16(packet, 14) / 100.0;
          if (state.hasReceivedRealSummary && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealSummary is true. Ignoring mock summary packet.");
            break;
          }
          state = state.copyWith(
            basalSum: base,
            mealSum: morning + lunch + evening,
            appendSum: append,
            hasReceivedSummary: true,
            hasReceivedRealSummary: isRealPacket ? true : state.hasReceivedRealSummary,
          );
        }
        break;

      case Opcodes.btPumpPidRes:
        // 고유 PID 응답: [3..18] PID (16Byte)
        if (dataLen >= 16) {
          final pidBytes = packet.sublist(3, 19);
          final String pidStr = String.fromCharCodes(pidBytes).trim();
          CloudSyncService().currentPumpPid = pidStr;
          
          // 오프라인 큐에 UNKNOWN_PID로 대기중이던 패킷들을 진짜 PID로 업데이트
          SyncQueueDb().updateUnknownPumpIds(pidStr);

          state = state.copyWith(pumpPid: pidStr);
        }
        break;

      case Opcodes.btPumpFwRes:
        // 펌웨어 버전 응답: [3..4] 버전 (2Byte)
        if (dataLen >= 2) {
          final int major = packet[3];
          final int minor = packet[4];
          if (state.hasReceivedRealFirmware && !isRealPacket) {
            print("[DEBUG] PumpStateNotifier: hasReceivedRealFirmware is true. Ignoring mock firmware version packet.");
            break;
          }
          state = state.copyWith(
            firmwareVersion: "v$major.$minor",
            hasReceivedRealFirmware: isRealPacket ? true : state.hasReceivedRealFirmware,
          );
        }
        break;

      case Opcodes.btPrsAppPasswdRes:
      case Opcodes.btNewAppPasswdInd:
        // 패스워드 응답/알림: [3..8] 숫자 패스워드 (6Byte)
        if (dataLen >= 6) {
          final passwordBytes = packet.sublist(3, 9);
          final passwordStr = passwordBytes.map((b) => b.toString()).join().trim();
          if (passwordStr.isNotEmpty) {
            state = state.copyWith(
              password: passwordStr,
              isPasswordProvisioned: true,
            );
          }
        }
        break;
    }
  }

  /// 상태 강제 조작 기능 (UI 프리뷰 및 단위 테스트용)
  void setInjecting(bool injecting) {
    state = state.copyWith(
      isPumpInjecting: injecting,
      connectionState: injecting ? PumpState.injecting : PumpState.idle,
    );
  }

  /// 운동 감량 모드 상태 강제 설정 (앱에서 시작 성공 시)
  void setExerciseActive(bool active) {
    state = state.copyWith(
      isExerciseActive: active,
    );
  }

  /// 인슐린 잔량 강제 수정 기능 (테스트용)
  void setInsulinRemaining(double unit) {
    state = state.copyWith(insulinRemaining: unit);
  }

  /// 배터리 레벨 강제 수정 기능 (테스트용)
  void setBatteryLevel(int level) {
    state = state.copyWith(batteryLevel: level.clamp(0, 4));
  }

  /// 비밀번호 강제 수정 기능 (테스트용)
  void setPasswordForce(String newPassword) {
    state = state.copyWith(password: newPassword);
  }

  /// 기초 설정 속도 리스트 업데이트 (웹뷰 연동)
  void updateBasalRates(List<double> rates) {
    state = state.copyWith(
      basalRates: List.from(rates),
      hasReceivedRealBasal: true,
    );
  }

  /// 식사 설정 값 업데이트
  void updateMealSettings(double breakfast, double lunch, double dinner) {
    state = state.copyWith(
      mealSettings: {
        'breakfast': breakfast,
        'lunch': lunch,
        'dinner': dinner,
      },
    );
  }
}

/// 전역 펌프 상태 프로바이더
final pumpStateProvider = StateNotifierProvider<PumpStateNotifier, PumpStateData>((ref) {
  return PumpStateNotifier();
});
