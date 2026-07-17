import 'dart:async';
import 'opcodes.dart';

/// 10Byte 청크 스트림을 수신하여 20Byte 논리 패킷으로 결합하고
/// 프레임 동기화 유실 시 0xEF(kStartCode)를 찾아 복구하는 패킷 조립기
class BlePacketAssembler {
  final List<int> _rxBuffer = [];
  final StreamController<List<int>> _packetStreamController = StreamController<List<int>>.broadcast();
  Timer? _timeoutTimer;
  bool bypassTimeoutHold = false;
  bool _isBulkDataMode = false; // 대량 패킷 모드 플래그

  /// 재조립 타임아웃 시 재연결을 시도할 외부 콜백
  void Function()? onTimeoutReconnect;

  BlePacketAssembler({this.onTimeoutReconnect});

  /// 조립이 완료된 20Byte 패킷 스트림
  Stream<List<int>> get packetStream => _packetStreamController.stream;

  /// 현재 수신 버퍼의 복사본 (테스트 및 디버깅용)
  List<int> get rxBuffer => List.unmodifiable(_rxBuffer);

  /// 물리 계층에서 청크가 수신될 때 호출되는 핸들러
  void onChunkReceived(List<int> chunk) {
    if (chunk.isEmpty) return;
    print("[V15] BLE 원시 수신 데이터 (길이: ${chunk.length}): $chunk");

    // 새로운 청크 수신 시 이전 대기 타이머 제거
    _timeoutTimer?.cancel();

    _rxBuffer.addAll(chunk);

    while (true) {
      if (_isBulkDataMode) {
        if (_rxBuffer.length >= 20) {
          List<int> completePacket = _rxBuffer.sublist(0, 20);
          _rxBuffer.removeRange(0, 20);
          
          if (completePacket[0] == kStartCode && completePacket[1] == Opcodes.btDataEndInd) {
            _isBulkDataMode = false;
          }
          
          _packetStreamController.add(completePacket);
          continue;
        } else {
          // 대량 패킷 모드 중이나 20바이트 미만인 경우 대기
          if (_rxBuffer.isNotEmpty && !bypassTimeoutHold) {
            _timeoutTimer = Timer(const Duration(milliseconds: 500), _handleTimeout);
          }
          break;
        }
      }

      // 1. 버퍼 내에서 시작 코드(0xEF)의 첫 위치를 검색
      final index = _rxBuffer.indexOf(kStartCode);
      if (index == -1) {
        // 시작 코드가 전혀 없으면 버퍼 내의 모든 데이터는 가비지이므로 전체 비움
        _rxBuffer.clear();
        break;
      }

      // 2. 시작 코드 앞의 무효한 쓰레기 데이터 제거
      if (index > 0) {
        _rxBuffer.removeRange(0, index);
      }

      // 3. 시작 코드가 선두에 있는 상태에서 온전한 20바이트 패킷이 채워졌는지 확인
      if (_rxBuffer.length >= 20) {
        List<int> completePacket = _rxBuffer.sublist(0, 20);
        _rxBuffer.removeRange(0, 20);
        
        if (completePacket[0] == kStartCode && completePacket[1] == Opcodes.btDataStartInd) {
          _isBulkDataMode = true;
        }
        
        _packetStreamController.add(completePacket);
      } else {
        // 0xEF로 시작은 하나 20바이트 미만인 경우 다음 청크 입력을 대기하며 500ms 타이머 기동 (Hold 플래그 확인)
        if (_rxBuffer.isNotEmpty && !bypassTimeoutHold) {
          _timeoutTimer = Timer(const Duration(milliseconds: 500), _handleTimeout);
        }
        break;
      }
    }
  }

  void _handleTimeout() {
    if (_rxBuffer.isNotEmpty) {
      print("[V16] 500ms 타임아웃 발생! 남은 ${_rxBuffer.length}바이트 버퍼를 패킷으로 강제 방출합니다: $_rxBuffer");
      _packetStreamController.add(List.from(_rxBuffer));
      _rxBuffer.clear();
    }
    onTimeoutReconnect?.call();
  }

  /// 자원 해제
  void dispose() {
    _timeoutTimer?.cancel();
    _packetStreamController.close();
  }
}
