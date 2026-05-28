import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble/opcodes.dart';
import '../services/ble/packet_parser.dart';

/// HealUs 펌프의 전역 상태 모델
class PumpStateData {
  /// 현재 펌프 기기 상태 (대기, 주입중, 오류정지 등)
  final PumpState connectionState;

  /// 인슐린 주입 중 여부 (UI Lock 트리거 대상)
  final bool isPumpInjecting;

  /// 배터리 잔량 레벨 (0: Empty ~ 4: Full)
  final int batteryLevel;

  /// 인슐린 잔량 (Unit 단위, 소수점 포함)
  final double insulinRemaining;

  PumpStateData({
    this.connectionState = PumpState.idle,
    this.isPumpInjecting = false,
    this.batteryLevel = 4,
    this.insulinRemaining = 300.0,
  });

  PumpStateData copyWith({
    PumpState? connectionState,
    bool? isPumpInjecting,
    int? batteryLevel,
    double? insulinRemaining,
  }) {
    return PumpStateData(
      connectionState: connectionState ?? this.connectionState,
      isPumpInjecting: isPumpInjecting ?? this.isPumpInjecting,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      insulinRemaining: insulinRemaining ?? this.insulinRemaining,
    );
  }
}

/// 펌프의 상태 관리를 수행하는 StateNotifier
class PumpStateNotifier extends StateNotifier<PumpStateData> {
  PumpStateNotifier() : super(PumpStateData());

  /// 20Byte BLE 논리 패킷을 입력받아 전역 상태를 업데이트합니다.
  void handleIncomingPacket(List<int> packet) {
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
        if (dataLen >= 1) {
          final level = packet[3];
          state = state.copyWith(batteryLevel: level.clamp(0, 4));
        }
        break;

      case Opcodes.btSetRes:
        // BT_SET_RES: [3..8] set_date (6B), [9..10] insul_remain (2B) -> offset 9
        if (dataLen >= 8) {
          final insulRaw = PacketParser.readUint16(packet, 9);
          state = state.copyWith(insulinRemaining: insulRaw / 100.0);
        }
        break;

      case Opcodes.btInjInfoRes:
        // BT_INJ_INFO_RES: [3] inj_info, [4..9] set_date (6B), [10..11] insul_set, [12..13] insul_remain -> offset 12
        if (dataLen >= 11) {
          final insulRaw = PacketParser.readUint16(packet, 12);
          state = state.copyWith(insulinRemaining: insulRaw / 100.0);
        }
        break;

      case Opcodes.btInjStartInd:
        // 주입 시작 시 UI Lock 오버레이 트리거
        state = state.copyWith(
          isPumpInjecting: true,
          connectionState: PumpState.injecting,
        );
        break;

      case Opcodes.btInjStopInd:
        // 주입 완료 시 UI Lock 오버레이 해제
        state = state.copyWith(
          isPumpInjecting: false,
          connectionState: PumpState.idle,
        );
        break;

      case Opcodes.btErrInd:
        // 오류 상태 발생 시 안전상 주입 락 상태는 해제하고, 기기는 오류 정지 상태로 전이
        state = state.copyWith(
          connectionState: PumpState.errorPause,
          isPumpInjecting: false,
        );
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

  /// 인슐린 잔량 강제 수정 기능 (테스트용)
  void setInsulinRemaining(double unit) {
    state = state.copyWith(insulinRemaining: unit);
  }

  /// 배터리 레벨 강제 수정 기능 (테스트용)
  void setBatteryLevel(int level) {
    state = state.copyWith(batteryLevel: level.clamp(0, 4));
  }
}

/// 전역 펌프 상태 프로바이더
final pumpStateProvider = StateNotifierProvider<PumpStateNotifier, PumpStateData>((ref) {
  return PumpStateNotifier();
});
