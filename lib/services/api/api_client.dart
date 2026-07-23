import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/cloud_config.dart';
import '../database/local_db.dart'; // For PumpLogModel

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Raw Packet Buffering
  final List<Map<String, dynamic>> _rawPacketBuffer = [];
  Timer? _rawPacketTimer;
  final int _maxBufferSize = 10;
  final Duration _flushInterval = const Duration(seconds: 3);

  /// 펌프 이력 데이터(Bulk) 서버로 전송
  Future<void> postBulkLogs(List<PumpLogModel> logs, String deviceMac) async {
    if (!CloudConfig.enableCloudSync) return;
    if (logs.isEmpty) return;

    try {
      final url = Uri.parse('${CloudConfig.serverBaseUrl}/api/logs');
      final payload = {
        "logs": logs.map((log) => {
          "device_mac": deviceMac,
          "month": log.month,
          "day": log.day,
          "base_total": log.baseTotal,
          "eat_total": log.eatTotal,
          "morning_total": log.morningTotal,
          "afternoon_total": log.afternoonTotal,
          "evening_total": log.eveningTotal,
          "append_total": log.appendTotal,
          "created_at": log.createdAt,
        }).toList()
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('[ApiClient] Successfully posted bulk logs.');
      } else {
        print('[ApiClient] Failed to post logs: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiClient] Exception posting bulk logs: $e');
    }
  }

  /// 원시 패킷(Raw Packet) 버퍼에 추가 (버퍼 꽉 차면 전송)
  void bufferRawPacket(List<int> packet, String direction, String deviceMac) {
    if (!CloudConfig.enableCloudSync) return;

    _rawPacketBuffer.add({
      "device_mac": deviceMac,
      "direction": direction, // 'TX' or 'RX'
      "payload_hex": packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
      "timestamp": DateTime.now().toIso8601String(),
    });

    if (_rawPacketBuffer.length >= _maxBufferSize) {
      _flushRawPackets();
    } else {
      _rawPacketTimer?.cancel();
      _rawPacketTimer = Timer(_flushInterval, _flushRawPackets);
    }
  }

  /// 버퍼에 모인 패킷들을 서버로 일괄 전송
  Future<void> _flushRawPackets() async {
    if (_rawPacketBuffer.isEmpty) return;

    final packetsToSend = List<Map<String, dynamic>>.from(_rawPacketBuffer);
    _rawPacketBuffer.clear();
    _rawPacketTimer?.cancel();

    try {
      final url = Uri.parse('${CloudConfig.serverBaseUrl}/api/raw_logs');
      final payload = {"packets": packetsToSend};

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('[ApiClient] Successfully posted ${packetsToSend.length} raw packets.');
      } else {
        print('[ApiClient] Failed to post raw packets: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiClient] Exception posting raw packets: $e');
    }
  }
}
