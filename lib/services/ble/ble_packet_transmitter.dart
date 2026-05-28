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
  /// 20바이트의 패킷을 10바이트씩 2회로 분할하여 전송합니다.
  /// 1차 전송 후 인슐린 펌프 마이컴의 오버플로우 방지를 위해 30ms 물리 지연을 강제합니다.
  Future<void> send20BytePacket(BleWriter writer, List<int> logicalPacket) async {
    if (logicalPacket.length != 20) {
      throw ArgumentError("무결성이 깨진 잘못된 논리 패킷 요청입니다. (길이: ${logicalPacket.length})");
    }
    if (logicalPacket[0] != kStartCode) {
      throw ArgumentError("패킷의 시작 코드가 0xEF가 아닙니다.");
    }

    final firstChunk = logicalPacket.sublist(0, 10);
    final secondChunk = logicalPacket.sublist(10, 20);

    // 1. 첫 번째 10Byte 청크 전송
    await writer.write(firstChunk, withoutResponse: true);

    // 2. 하드웨어 처리 마진 확보를 위한 30ms 물리적 딜레이 블로킹
    await Future.delayed(const Duration(milliseconds: 30));

    // 3. 두 번째 10Byte 청크 전송
    await writer.write(secondChunk, withoutResponse: true);
  }
}
