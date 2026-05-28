import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/state/pump_state_provider.dart';

void main() {
  group('PumpStateProvider / PumpStateNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('초기 상태 값을 정상적으로 가진다', () {
      final state = container.read(pumpStateProvider);
      expect(state.connectionState, PumpState.idle);
      expect(state.isPumpInjecting, false);
      expect(state.batteryLevel, 4);
      expect(state.insulinRemaining, 300.0);
    });

    test('BT_STATE_IND 패킷 수신 시 상태 값과 주입 플래그를 실시간 반영한다', () {
      final notifier = container.read(pumpStateProvider.notifier);

      // 주입 중 상태 패킷 (0x02)
      final stateInjPacket = List<int>.filled(20, 0);
      stateInjPacket[0] = kStartCode;
      stateInjPacket[1] = Opcodes.btStateInd;
      stateInjPacket[2] = 1; // dataLen
      stateInjPacket[3] = 0x02; // state_inj

      notifier.handleIncomingPacket(stateInjPacket);

      var updatedState = container.read(pumpStateProvider);
      expect(updatedState.connectionState, PumpState.injecting);
      expect(updatedState.isPumpInjecting, true);

      // 대기 상태 패킷 (0x01)
      final stateIdlePacket = List<int>.filled(20, 0);
      stateIdlePacket[0] = kStartCode;
      stateIdlePacket[1] = Opcodes.btStateInd;
      stateIdlePacket[2] = 1; // dataLen
      stateIdlePacket[3] = 0x01; // state_idle

      notifier.handleIncomingPacket(stateIdlePacket);

      updatedState = container.read(pumpStateProvider);
      expect(updatedState.connectionState, PumpState.idle);
      expect(updatedState.isPumpInjecting, false);
    });

    test('BT_BATT_DATA_IND 패킷 수신 시 배터리 단계를 업데이트한다', () {
      final notifier = container.read(pumpStateProvider.notifier);

      final battPacket = List<int>.filled(20, 0);
      battPacket[0] = kStartCode;
      battPacket[1] = Opcodes.btBattDataInd;
      battPacket[2] = 1; // dataLen
      battPacket[3] = 0x02; // 배터리 레벨 2 (중간)

      notifier.handleIncomingPacket(battPacket);

      final updatedState = container.read(pumpStateProvider);
      expect(updatedState.batteryLevel, 2);
    });

    test('BT_SET_RES 수신 시 인슐린 잔량 정수를 소수점으로 환산하여 업데이트한다', () {
      final notifier = container.read(pumpStateProvider.notifier);

      final setResPacket = List<int>.filled(20, 0);
      setResPacket[0] = kStartCode;
      setResPacket[1] = Opcodes.btSetRes;
      setResPacket[2] = 8; // dataLen (date 6B + insul_remain 2B = 8B)
      
      // insul_remain: index 9, 10
      // 123.45 Unit -> 스케일링 팩 100 적용하여 12345 전달
      // 12345 = 0x3039 (Little-endian: 0x39, 0x30)
      setResPacket[9] = 0x39;
      setResPacket[10] = 0x30;

      notifier.handleIncomingPacket(setResPacket);

      final updatedState = container.read(pumpStateProvider);
      expect(updatedState.insulinRemaining, 123.45);
    });

    test('BT_INJ_INFO_RES 수신 시 인슐린 잔량을 실시간 반영한다', () {
      final notifier = container.read(pumpStateProvider.notifier);

      final infoResPacket = List<int>.filled(20, 0);
      infoResPacket[0] = kStartCode;
      infoResPacket[1] = Opcodes.btInjInfoRes;
      infoResPacket[2] = 11; // dataLen (inj_info 1B + date 6B + insul_set 2B + insul_remain 2B = 11B)
      
      // insul_remain: index 12, 13
      // 250.50 Unit -> 25050 (0x61DA -> Little-endian: 0xDA, 0x61)
      infoResPacket[12] = 0xDA;
      infoResPacket[13] = 0x61;

      notifier.handleIncomingPacket(infoResPacket);

      final updatedState = container.read(pumpStateProvider);
      expect(updatedState.insulinRemaining, 250.50);
    });

    test('BT_ERR_IND 패킷 수신 시 오류정지 상태로 변경되고 주입 락을 해제한다', () {
      final notifier = container.read(pumpStateProvider.notifier);
      
      // 먼저 주입 중 상태로 설정
      notifier.setInjecting(true);
      expect(container.read(pumpStateProvider).isPumpInjecting, true);

      final errPacket = List<int>.filled(20, 0);
      errPacket[0] = kStartCode;
      errPacket[1] = Opcodes.btErrInd;
      errPacket[2] = 1;
      errPacket[3] = 0x01; // 주사기 바늘 막힘 에러

      notifier.handleIncomingPacket(errPacket);

      final updatedState = container.read(pumpStateProvider);
      expect(updatedState.connectionState, PumpState.errorPause);
      expect(updatedState.isPumpInjecting, false); // 안전을 위해 주입 락 해제 및 정지
    });
  });
}
