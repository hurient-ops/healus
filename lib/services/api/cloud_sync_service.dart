import 'dart:async';
import 'api_client.dart';

class RawPacketEvent {
  final List<int> packet;
  final String direction;
  final String deviceMac;

  RawPacketEvent({
    required this.packet,
    required this.direction,
    required this.deviceMac,
  });
}

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;

  final StreamController<RawPacketEvent> _packetStreamController = StreamController<RawPacketEvent>.broadcast();

  CloudSyncService._internal() {
    // Observer 패턴: 이벤트가 발생하면 ApiClient를 통해 버퍼링/전송
    _packetStreamController.stream.listen((event) {
      ApiClient().bufferRawPacket(event.packet, event.direction, event.deviceMac);
    });
  }

  /// 현재 연결된 펌프의 PID (클라우드 전송 식별자로 사용)
  String currentPumpPid = "UNKNOWN_PID";

  /// BLE 패킷 전송 시 호출 (TX)
  void emitTxPacket(List<int> packet, {String? deviceMac}) {
    _packetStreamController.add(RawPacketEvent(packet: packet, direction: 'TX', deviceMac: currentPumpPid));
  }

  /// BLE 패킷 수신 시 호출 (RX)
  void emitRxPacket(List<int> packet, {String? deviceMac}) {
    _packetStreamController.add(RawPacketEvent(packet: packet, direction: 'RX', deviceMac: currentPumpPid));
  }
}
