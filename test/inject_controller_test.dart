import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/services/ble/ble_service_interface.dart';
import 'package:healus/services/ble/ble_service_provider.dart';
import 'package:healus/services/inject/inject_controller.dart';

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
  group('InjectController Tests', () {
    late ProviderContainer container;
    late TestBleService testBleService;

    setUp(() {
      testBleService = TestBleService();
      container = ProviderContainer(
        overrides: [
          // bleServiceProvider 재정의하여 TestBleService 주입
          bleServiceProvider.overrideWithValue(testBleService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('주입 요청 시 인슐린 양을 x100 스케일 정수로 변환하여 20Byte 패킷을 정상 생성 및 전송한다', () async {
      final controller = container.read(injectControllerProvider.notifier);

      // 1.5 Unit 식사 주입(0) 요청
      controller.requestInjection(1.5, 0);

      // 비동기 큐 전송 대기 (75ms 딜레이 감안)
      await Future.delayed(const Duration(milliseconds: 150));

      expect(testBleService.writtenPackets.length, 1); // logical 20Byte 패킷 1개
      
      final totalPacket = testBleService.writtenPackets[0];
      expect(totalPacket[0], kStartCode);
      expect(totalPacket[1], Opcodes.btInjReq);
      expect(totalPacket[2], 3); // data length
      expect(totalPacket[3], 0); // injSel (식사주입)
      
      // 1.5 Unit -> 150 (0x0096 -> Little-endian: 0x96, 0x00)
      expect(totalPacket[4], 0x96);
      expect(totalPacket[5], 0x00);
    });

    test('긴급 정지 요청 시 BT_INJ_STOP_REQ 패킷이 생성되어 즉시 송신된다', () async {
      final controller = container.read(injectControllerProvider.notifier);

      controller.requestEmergencyStop();

      await Future.delayed(const Duration(milliseconds: 150));

      expect(testBleService.writtenPackets.length, 1);
      
      final totalPacket = testBleService.writtenPackets[0];
      expect(totalPacket[0], kStartCode);
      expect(totalPacket[1], Opcodes.btInjStopReq);
      expect(totalPacket[2], 1); // data length
      expect(totalPacket[3], 0x01); // pause_state = TRUE
    });

    test('선점형 패킷 큐 관리를 통해 긴급 정지가 대기 중인 일반 패킷보다 먼저 전송된다', () async {
      // 1. 우선 기기 미연결 상태(isConnected = false)로 설정하여 큐 진행을 멈춤
      testBleService._connected = false;

      final controller = container.read(injectControllerProvider.notifier);

      // 일반 주입 패킷 2개 요청
      controller.requestInjection(2.0, 0); // 첫 번째 대기
      controller.requestInjection(3.5, 1); // 두 번째 대기

      // 현재 대기 큐 크기 검증
      expect(container.read(injectControllerProvider).length, 2);

      // 긴급 정지 호출
      controller.requestEmergencyStop();

      // 대기 큐에 3개가 들어있어야 함
      final currentQueue = container.read(injectControllerProvider);
      expect(currentQueue.length, 3);

      // 첫 번째 대기 항목이 긴급 정지 패킷(0x37)이어야 함
      expect(currentQueue[0][1], Opcodes.btInjStopReq);
      expect(currentQueue[1][1], Opcodes.btInjReq);
      expect(currentQueue[2][1], Opcodes.btInjReq);
    });
  });
}
