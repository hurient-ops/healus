import 'package:flutter_test/flutter_test.dart';
import 'package:healus/services/ble/opcodes.dart';
import 'package:healus/services/ble/ble_packet_assembler.dart';
import 'package:healus/services/ble/ble_packet_transmitter.dart';
import 'package:healus/services/ble/packet_parser.dart';

/// 단위 테스트를 위한 Mock BLE Writer
class MockBleWriter implements BleWriter {
  final List<List<int>> writtenChunks = [];
  final List<DateTime> writeTimes = [];

  @override
  Future<void> write(List<int> value, {bool withoutResponse = false}) async {
    writtenChunks.add(value);
    writeTimes.add(DateTime.now());
  }
}

void main() {
  group('BlePacketAssembler Tests', () {
    late BlePacketAssembler assembler;

    setUp(() {
      assembler = BlePacketAssembler();
    });

    tearDown(() {
      assembler.dispose();
    });

    test('정상적인 10Byte 청크 2개가 입력되면 20Byte 패킷 1개가 조립되어 출력된다', () async {
      final List<List<int>> results = [];
      assembler.packetStream.listen((packet) {
        results.add(packet);
      });

      // 1. 첫 번째 청크 (0xEF로 시작)
      final chunk1 = [kStartCode, 0x05, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
      // 2. 두 번째 청크
      final chunk2 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];

      assembler.onChunkReceived(chunk1);
      assembler.onChunkReceived(chunk2);

      // 비동기 처리 대기
      await Future.delayed(const Duration(milliseconds: 10));

      expect(results.length, 1);
      expect(results[0].length, 20);
      expect(results[0][0], kStartCode);
      expect(results[0][1], 0x05); // Opcode (btStateInd)
    });

    test('프레임 동기화 유실 시 0xEF를 찾을 때까지 버퍼를 쉬프트 복구한다', () async {
      final List<List<int>> results = [];
      assembler.packetStream.listen((packet) {
        results.add(packet);
      });

      // 1. 쓰레기 청크 전송 (0xEF로 시작하지 않음)
      final garbageChunk = [0x99, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00];
      // 2. 동기화 유실 후 정상 시작되는 청크 (중간인 index 3에 0xEF 위치)
      final syncChunk = [0xAA, 0xBB, 0xCC, kStartCode, 0x05, 0x01, 0x00, 0x00, 0x00, 0x00];
      // 3. 두 번째 정상 청크 (패킷을 완성하기 위한 청크)
      final lastChunk = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA];
      // 4. 세 번째 정상 청크 (20바이트 완성을 채우기 위한 청크)
      final extraChunk = [0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x01, 0x02, 0x03, 0x04];

      assembler.onChunkReceived(garbageChunk);
      assembler.onChunkReceived(syncChunk);
      assembler.onChunkReceived(lastChunk);
      assembler.onChunkReceived(extraChunk);

      await Future.delayed(const Duration(milliseconds: 10));

      // 결과적으로 0xEF 이후의 20바이트 패킷이 조립되어 전달되어야 함
      expect(results.length, 1);
      expect(results[0][0], kStartCode);
      expect(results[0][1], 0x05);
      expect(results[0][19], 0xDD); // 0xEF(0) + syncChunk[4..9](6) + lastChunk[0..9](10) + extraChunk[0..2](3) = 20바이트. extraChunk[2]는 0xDD임.
    });

    test('10바이트가 아닌 청크는 비정상 데이터로 판단하여 수신하지 않는다', () async {
      final List<List<int>> results = [];
      assembler.packetStream.listen((packet) {
        results.add(packet);
      });

      final invalidChunk = [kStartCode, 0x05, 0x01]; // 3바이트 청크

      assembler.onChunkReceived(invalidChunk);
      expect(assembler.rxBuffer.isEmpty, true);
    });
  });

  group('BlePacketTransmitter Tests', () {
    late BlePacketTransmitter transmitter;
    late MockBleWriter mockWriter;

    setUp(() {
      transmitter = BlePacketTransmitter();
      mockWriter = MockBleWriter();
    });

    test('20Byte 논리 패킷을 10Byte 단위로 쪼개어 75ms 간격을 두고 전송한다', () async {
      final logicalPacket = List<int>.generate(20, (i) => i);
      logicalPacket[0] = kStartCode; // 첫 바이트 0xEF로 설정

      await transmitter.send20BytePacket(mockWriter, logicalPacket);

      // 전송된 횟수와 크기 검증
      expect(mockWriter.writtenChunks.length, 2);
      expect(mockWriter.writtenChunks[0].length, 10);
      expect(mockWriter.writtenChunks[1].length, 10);

      // 첫 10바이트, 다음 10바이트 매핑 검증
      expect(mockWriter.writtenChunks[0], [0xEF, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(mockWriter.writtenChunks[1], [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);

      // 75ms 딜레이 블로킹 검증
      final diff = mockWriter.writeTimes[1].difference(mockWriter.writeTimes[0]);
      expect(diff.inMilliseconds >= 75, true);
    });

    test('길이가 20바이트가 아니거나 0xEF로 시작하지 않는 패킷은 예외를 던진다', () async {
      final invalidLenPacket = [kStartCode, 0x01, 0x02];
      final invalidStartPacket = List<int>.generate(20, (i) => i); // index 0이 0임

      expect(() => transmitter.send20BytePacket(mockWriter, invalidLenPacket), throwsArgumentError);
      expect(() => transmitter.send20BytePacket(mockWriter, invalidStartPacket), throwsArgumentError);
    });
  });

  group('BlePacketAssembler Reassembly Timeout Tests', () {
    late BlePacketAssembler assembler;

    setUp(() {
      assembler = BlePacketAssembler();
    });

    tearDown(() {
      assembler.dispose();
    });

    test('10바이트만 전송받은 뒤 500ms가 지나면 재조립 타임아웃이 발생하여 버퍼가 비워지고 콜백이 유발된다', () async {
      bool isReconnectCalled = false;
      assembler.onTimeoutReconnect = () {
        isReconnectCalled = true;
      };

      final chunk = [kStartCode, 0x05, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
      assembler.onChunkReceived(chunk);

      expect(assembler.rxBuffer.length, 10);
      expect(isReconnectCalled, false);

      // 550ms 대기 (타임아웃 발생 유도)
      await Future.delayed(const Duration(milliseconds: 550));

      expect(assembler.rxBuffer.isEmpty, true);
      expect(isReconnectCalled, true);
    });
  });

  group('PacketParser Tests', () {
    test('Little-endian 정수(16비트, 32비트)를 올바르게 디코딩/인코딩한다', () {
      final buffer = List<int>.filled(10, 0);

      // Uint16
      PacketParser.writeUint16(buffer, 2, 12345);
      expect(PacketParser.readUint16(buffer, 2), 12345);

      // Uint32
      PacketParser.writeUint32(buffer, 4, 987654321);
      expect(PacketParser.readUint32(buffer, 4), 987654321);
    });

    test('6Byte DATE 포맷을 DateTime 객체로 정상 변환하고 역변환한다', () {
      // 17년 9월 8일 7시 5분 35초
      final dateBytes = [17, 9, 8, 7, 5, 35];
      final parsedDate = PacketParser.parseDate(dateBytes);

      expect(parsedDate.year, 2017);
      expect(parsedDate.month, 9);
      expect(parsedDate.day, 8);
      expect(parsedDate.hour, 7);
      expect(parsedDate.minute, 5);
      expect(parsedDate.second, 35);

      final serialized = PacketParser.serializeDate(parsedDate);
      expect(serialized, dateBytes);
    });
  });
}
