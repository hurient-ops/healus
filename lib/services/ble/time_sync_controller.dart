import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healus/services/ble/ble_service_provider.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/services/ble/packet_parser.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'ble_mutex.dart';

final timeSyncControllerProvider = StateNotifierProvider<TimeSyncController, bool>((ref) {
  return TimeSyncController(ref);
});

class TimeSyncController extends StateNotifier<bool> {
  final Ref _ref;
  Timer? _retryTimer;
  bool _isSyncing = false;

  TimeSyncController(this._ref) : super(false);

  Future<void> startTimeSync(WebViewController webViewController) async {
    if (state) return; // 이미 동기화 완료됨
    if (_isSyncing) return; // 이미 진행 중
    
    _isSyncing = true;
    _retryTimer?.cancel();
    
    await _attemptSync(webViewController);
    
    if (!state) {
      // 실패 시 30분 주기 재시도 타이머 가동
      _retryTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
        if (!state && !_isSyncing) {
          _attemptSync(webViewController);
        } else if (state) {
          timer.cancel();
        }
      });
    }
  }

  Future<void> _attemptSync(WebViewController webViewController) async {
    _isSyncing = true;
    final mutex = _ref.read(bleMutexProvider);
    await mutex.acquire();

    try {
      final bleService = _ref.read(bleServiceProvider);
      final bypassHold = _ref.read(timeoutHoldProvider);
      
      final now = DateTime.now();
      final timeBytes = PacketParser.serializeDate(now);

      print("시간 동기화: BT_CUR_TIME_IND (0x06) 송신");
      final timeIndPacket = List<int>.filled(20, 0);
      timeIndPacket[0] = kStartCode;
      timeIndPacket[1] = Opcodes.btCurTimeInd;
      timeIndPacket[2] = 6;
      timeIndPacket.setRange(3, 9, timeBytes);
      
      await bleService.sendPacket(timeIndPacket);

      // 3초 대기 (단, Hold 켜져있으면 365일 무한 대기)
      final timeoutDuration = bypassHold ? const Duration(days: 365) : const Duration(seconds: 3);

      final Completer<List<int>> completer = Completer<List<int>>();
      final subscription = bleService.receivedPacketsStream.listen((packet) {
        if (packet[1] == Opcodes.btCurTimeRes) {
          if (!completer.isCompleted) {
            completer.complete(packet);
          }
        }
      });

      List<int> timeResPacket;
      try {
        timeResPacket = await completer.future.timeout(timeoutDuration);
      } catch (e) {
        throw Exception("시간 동기화 타임아웃 발생");
      } finally {
        await subscription.cancel();
      }

      final resBytes = timeResPacket.sublist(3, 9);
      
      bool match = true;
      for (int i = 0; i < 6; i++) {
        if (timeBytes[i] != resBytes[i]) {
          match = false;
          break;
        }
      }

      if (match) {
        print("시간 동기화 성공");
        state = true;
        _retryTimer?.cancel();
        _triggerSuccessToast(webViewController);
      } else {
        print("시간 동기화 불일치");
        _triggerFailToast(webViewController);
      }
    } catch (e) {
      print("시간 동기화 에러: $e");
      _triggerFailToast(webViewController);
    } finally {
      mutex.release();
      _isSyncing = false;
    }
  }

  void _triggerSuccessToast(WebViewController webViewController) {
    try {
      webViewController.runJavaScript('''
        (function() {
          var attempt = 0;
          var interval = setInterval(function() {
            if (typeof window.showToast === 'function') {
              window.showToast('시간 동기화에 성공하였습니다.');
              clearInterval(interval);
            } else if (typeof showToast === 'function') {
              showToast('시간 동기화에 성공하였습니다.');
              clearInterval(interval);
            }
            attempt++;
            if (attempt > 40) clearInterval(interval); // 2초 뒤 포기
          }, 50);
        })();
      ''');
    } catch (e) {
      print("웹뷰 토스트 호출 실패: $e");
    }
  }

  void _triggerFailToast(WebViewController webViewController) {
    try {
      // 대시보드의 전역 showToast 함수 호출 (로딩 지연 대비 재시도 루프)
      webViewController.runJavaScript('''
        (function() {
          var attempt = 0;
          var interval = setInterval(function() {
            if (typeof window.showToast === 'function') {
              window.showToast('시간 동기화에 실패했습니다');
              clearInterval(interval);
            } else if (typeof showToast === 'function') {
              showToast('시간 동기화에 실패했습니다');
              clearInterval(interval);
            }
            attempt++;
            if (attempt > 40) clearInterval(interval);
          }, 50);
        })();
      ''');
    } catch (e) {
      print("웹뷰 토스트 호출 실패: $e");
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
