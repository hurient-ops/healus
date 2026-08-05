import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../config/cloud_config.dart';
import '../database/local_db.dart'; // For PumpLogModel
import '../database/sync_queue_db.dart'; // For SyncQueueDb

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  
  final SyncQueueDb _syncQueueDb = SyncQueueDb();
  bool _isSyncing = false;
  
  ApiClient._internal() {
    _initConnectivity();
  }

  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        // Network restored! Try to flush the offline queue.
        _flushOfflineQueue();
      }
    });
  }

  /// 펌프 이력 데이터(Bulk) 서버로 전송
  Future<void> postBulkLogs(List<PumpLogModel> logs, String pumpId) async {
    if (!CloudConfig.enableCloudSync) return;
    if (logs.isEmpty) return;
    if (pumpId.isEmpty || pumpId == 'EMPTY' || pumpId == 'UNKNOWN_PID') {
      print('[ApiClient] Blocked bulk logs transmission: Invalid pumpId "$pumpId"');
      return;
    }

    try {
      final url = Uri.parse('${CloudConfig.serverBaseUrl}/api/logs');
      final payload = {
        "logs": logs.map((log) => {
          "pump_id": pumpId,
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
      print('[ApiClient] Exception posting bulk logs (Backend/Network Down): $e');
    }
  }

  Future<void> postPumpStatus(int battery, double insulin, String pumpId) async {
    if (!CloudConfig.enableCloudSync) return;
    if (pumpId.isEmpty || pumpId == 'EMPTY' || pumpId == 'UNKNOWN_PID') {
      print('[ApiClient] Blocked sending pump status because pumpId is invalid: $pumpId');
      return;
    }

    try {
      final url = Uri.parse('${CloudConfig.serverBaseUrl}/api/logs/pump-status/$pumpId');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'battery_level': battery,
          'insulin_remaining': insulin,
        }),
      );
      print('[ApiClient] postPumpStatus success: ${response.body}');
    } catch (e) {
      print('[ApiClient] postPumpStatus error: $e');
    }
  }

  /// 원시 패킷(Raw Packet) 오프라인 큐에 저장 후 전송 트리거
  Future<void> bufferRawPacket(List<int> packet, String direction, String pumpId) async {
    if (!CloudConfig.enableCloudSync) return;
    
    final payloadHex = packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    await _syncQueueDb.init();
    await _syncQueueDb.insertPacket(pumpId, direction, payloadHex, timestamp);
    print("[ApiClient] Buffered raw packet. pump_id: $pumpId, direction: $direction, payload: $payloadHex");

    // 2. 백그라운드 동기화 시도
    _flushOfflineQueue();
  }

  /// 로컬 큐에 쌓인 패킷들을 서버로 일괄 전송 (재시도 로직 포함)
  Future<void> _flushOfflineQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _syncQueueDb.init();
      var packetsToSend = await _syncQueueDb.getUnsyncedPackets(limit: 50);
      
      // 진짜 PID가 확인되지 않은 패킷은 전송하지 않고 보류
      packetsToSend = packetsToSend.where((p) {
        final pid = p['pump_id'] as String;
        return pid.isNotEmpty && pid != 'EMPTY' && pid != 'UNKNOWN_PID';
      }).toList();

      if (packetsToSend.isEmpty) {
        _isSyncing = false;
        return;
      }

      final url = Uri.parse('${CloudConfig.serverBaseUrl}/api/raw_logs');
      final payload = {"packets": packetsToSend};

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10)); // 10초 타임아웃 추가

      if (response.statusCode == 200) {
        print('[ApiClient] Successfully posted ${packetsToSend.length} queued packets.');
        // 3. 서버 전송 성공 시 큐에서 완전 삭제
        final idsToDelete = packetsToSend.map<int>((p) => p['id'] as int).toList();
        await _syncQueueDb.deletePackets(idsToDelete);
        
        // 남아있는 패킷이 더 있을 수 있으므로 재귀 호출
        _isSyncing = false;
        if (packetsToSend.length == 50) {
          _flushOfflineQueue();
        }
      } else {
        print('[ApiClient] Server returned error: ${response.statusCode}. Keeping data in queue.');
      }
    } catch (e) {
      print('[ApiClient] Network/Server unavailable: $e. Packets safely kept in local queue.');
    } finally {
      _isSyncing = false;
    }
  }
}
