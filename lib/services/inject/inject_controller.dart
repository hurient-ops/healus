import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/opcodes.dart';
import '../ble/packet_parser.dart';
import '../ble/ble_packet_transmitter.dart';

/// BLE 전송 도구 프로바이더
final bleTransmitterProvider = Provider<BlePacketTransmitter>((ref) {
  return BlePacketTransmitter();
});

/// BLE 쓰기 인터페이스 프로바이더 (실제 기기 연결 시 Override 하여 사용)
final bleWriterProvider = Provider<BleWriter?>((ref) {
  return null;
});

/// 인슐린 주입 제어 및 선점형 긴급 정지 큐를 관리하는 Controller
class InjectController extends StateNotifier<List<List<int>>> {
  final BlePacketTransmitter _transmitter;
  final Ref _ref;
  bool _isProcessing = false;

  InjectController(this._transmitter, this._ref) : super([]);

  /// 대기 중인 패킷 송신 큐의 복사본
  List<List<int>> get queue => List.unmodifiable(state);

  /// 일반 제어/조회 패킷을 송신 큐 맨 뒤에 삽입 (FIFO)
  void queuePacket(List<int> packet) {
    state = [...state, packet];
    _processQueue();
  }

  /// 긴급 정지와 같은 고순위 패킷을 큐의 맨 앞에 강제 삽입 (LIFO / Preemption)
  void queueEmergencyPacket(List<int> packet) {
    state = [packet, ...state];
    _processQueue();
  }

  /// 인슐린 주입 요청 (BT_INJ_REQ, 0x17)
  /// [injVal]: 주입할 인슐린 양 (Double Unit)
  /// [injSel]: 주입 유형 (0: 식사주입, 1: 추가주입)
  void requestInjection(double injVal, int injSel) {
    final packet = List<int>.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btInjReq;
    packet[2] = 3; // Data length
    packet[3] = injSel;

    // 의료 정밀도를 위한 x100 스케일링 정수 변환 (소수점 극복)
    final int scaledVal = (injVal * 100).round();
    PacketParser.writeUint16(packet, 4, scaledVal);

    queuePacket(packet);
  }

  /// 소프트웨어 최우선 긴급 정지 요청 (BT_INJ_STOP_REQ, 0x37)
  /// 이 명령은 대기 중인 모든 요청을 밀어내고 큐의 최선두(Preemption)로 진입합니다.
  void requestEmergencyStop() {
    final packet = List<int>.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btInjStopReq;
    packet[2] = 1; // Data length
    packet[3] = 0x01; // pause_state = TRUE (강제 정지 설정)

    queueEmergencyPacket(packet);
  }

  /// 비동기 전송 큐 처리 루프
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (state.isNotEmpty) {
      final writer = _ref.read(bleWriterProvider);
      if (writer == null) {
        // 기기가 아직 연결되지 않은 상태이면 대기를 멈추고 큐를 유지
        _isProcessing = false;
        return;
      }

      final currentPacket = state.first;
      // 큐에서 패킷 꺼내기
      state = state.sublist(1);

      try {
        await _transmitter.send20BytePacket(writer, currentPacket);
      } catch (e) {
        // 오류 로그 기록 처리 (현업 수준의 예외 방어)
        print("BLE 패킷 전송 오류 발생: $e");
      }
    }

    _isProcessing = false;
  }
}

/// 전역 주입 제어기 프로바이더
final injectControllerProvider = StateNotifierProvider<InjectController, List<List<int>>>((ref) {
  final transmitter = ref.read(bleTransmitterProvider);
  return InjectController(transmitter, ref);
});
