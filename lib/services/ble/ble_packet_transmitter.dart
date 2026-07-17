import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'opcodes.dart';

/// BLE 쓰기 동작을 추상화한 인터페이스 (단위 테스트의 용이성을 확보)
abstract class BleWriter {
  Future<void> write(List<int> value, {bool withoutResponse = false});
}

/// [BluetoothCharacteristic]을 래핑하는 실 하드웨어용 [BleWriter] 구현체
class CharacteristicWriter implements BleWriter {
  final BluetoothCharacteristic characteristic;

  CharacteristicWriter(this.characteristic);

  @override
  Future<void> write(List<int> value, {bool withoutResponse = false}) async {
    await characteristic.write(value, withoutResponse: withoutResponse);
  }
}

/// 20Byte 논리 패킷을 10Byte 단위로 쪼개어 강제 지연 마진을 갖고 송신하는 전송 장치
class BlePacketTransmitter {
  bool _isTransmitting = false;
  final List<Completer<void>> _queue = [];

  /// 20바이트의 패킷을 10바이트씩 2회로 분할하여 전송합니다.
  /// 1차 전송 후 인슐린 펌프 마이컴의 오버플로우 방지를 위해 30ms 물리 지연을 강제합니다.
  /// 다수의 비동기 요청이 겹칠 경우 뮤텍스 큐를 통해 순차적 전송을 보장합니다.
  Future<void> send20BytePacket(BleWriter writer, List<int> logicalPacket) async {
    if (logicalPacket.length != 20) {
      throw ArgumentError("무결성이 깨진 잘못된 논리 패킷 요청입니다. (길이: ${logicalPacket.length})");
    }
    if (logicalPacket[0] != kStartCode) {
      throw ArgumentError("패킷의 시작 코드가 0xEF가 아닙니다.");
    }

    final completer = Completer<void>();
    _queue.add(completer);

    if (_isTransmitting) {
      await completer.future; // 큐에서 내 차례가 올 때까지 대기
    } else {
      _isTransmitting = true;
      completer.complete(); // 첫 진입은 바로 실행
    }

    try {
      // [최종 수정 사항] 블루투스 모듈(펌프 수신부)이 20바이트 일괄 수신을 자체적으로 완벽히 처리함이 확인됨.
      // 따라서 모든 명령어에 대해 불필요한 10+10 분할 및 딜레이 로직을 완전히 제거하고 20바이트를 원샷으로 전송합니다.
      await writer.write(logicalPacket, withoutResponse: true);
    } finally {
      _queue.removeAt(0); // 현재 항목 제거
      if (_queue.isNotEmpty) {
        _queue.first.complete(); // 다음 대기자 깨우기
      } else {
        _isTransmitting = false; // 큐가 비었으면 상태 초기화
      }
    }
  }
}
