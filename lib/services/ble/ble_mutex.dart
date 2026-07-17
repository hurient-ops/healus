import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 전역에서 BLE 명령이 송신된 후 응답(또는 타임아웃)을 받을 때까지 
/// 다른 명령의 송신을 차단하여 1:1 송수신 Flow(순서 보장)를 강제하는 Mutex 큐
class BleMutex {
  bool _isLocked = false;
  final List<Completer<void>> _queue = [];

  /// 전송 락 획득 (이전 Flow가 끝나기 전에는 대기)
  Future<void> acquire() async {
    final completer = Completer<void>();
    _queue.add(completer);
    if (_isLocked) {
      await completer.future;
    } else {
      _isLocked = true;
      completer.complete();
    }
  }

  /// 전송 락 해제 (현재 Flow 종료, 다음 큐 항목 실행 허용)
  void release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
    }
    if (_queue.isNotEmpty) {
      _queue.first.complete();
    } else {
      _isLocked = false;
    }
  }
}

/// 전역 BleMutex 프로바이더
final bleMutexProvider = Provider<BleMutex>((ref) {
  return BleMutex();
});
