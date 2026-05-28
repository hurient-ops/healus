import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/services/ble/ble_packet_transmitter.dart';
import 'package:healus/services/inject/inject_controller.dart';
import 'ble_packet_assembler_test.dart'; // MockBleWriter 사용을 위해 임포트

void main() {
  group('InjectController Tests', () {
    late ProviderContainer container;
    late MockBleWriter mockWriter;

    setUp(() {
      mockWriter = MockBleWriter();
      container = ProviderContainer(
        overrides: [
          // Mock BLE Writer 주입
          bleWriterProvider.overrideWithValue(mockWriter),
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

      // 비동기 큐 전송 대기 (30ms 딜레이 감안)
      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockWriter.writtenChunks.length, 2); // 10Byte씩 2회
      
      // 조립된 총 패킷 복원
      final totalPacket = [...mockWriter.writtenChunks[0], ...mockWriter.writtenChunks[1]];
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

      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockWriter.writtenChunks.length, 2);
      
      final totalPacket = [...mockWriter.writtenChunks[0], ...mockWriter.writtenChunks[1]];
      expect(totalPacket[0], kStartCode);
      expect(totalPacket[1], Opcodes.btInjStopReq);
      expect(totalPacket[2], 1); // data length
      expect(totalPacket[3], 0x01); // pause_state = TRUE
    });

    test('선점형 패킷 큐 관리를 통해 긴급 정지가 대기 중인 일반 패킷보다 먼저 전송된다', () async {
      // 1. 우선 기기 미연결 상태(bleWriter = null)로 설정하여 큐 진행을 멈춤
      final stoppedContainer = ProviderContainer(
        overrides: [
          bleWriterProvider.overrideWithValue(null),
        ],
      );

      final controller = stoppedContainer.read(injectControllerProvider.notifier);

      // 일반 주입 패킷 2개 요청
      controller.requestInjection(2.0, 0); // 첫 번째 대기
      controller.requestInjection(3.5, 1); // 두 번째 대기

      // 현재 대기 큐 크기 검증
      expect(stoppedContainer.read(injectControllerProvider).length, 2);

      // 긴급 정지 호출
      controller.requestEmergencyStop();

      // 대기 큐에 3개가 들어있어야 함
      final currentQueue = stoppedContainer.read(injectControllerProvider);
      expect(currentQueue.length, 3);

      // 첫 번째 대기 항목이 긴급 정지 패킷(0x37)이어야 함
      expect(currentQueue[0][1], Opcodes.btInjStopReq);
      expect(currentQueue[1][1], Opcodes.btInjReq);
      expect(currentQueue[2][1], Opcodes.btInjReq);

      stoppedContainer.dispose();
    });
  });
}
