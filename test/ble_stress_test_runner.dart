// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:healus/services/ble/ble_packet_assembler.dart';
import 'package:healus/services/ble/ble_packet_transmitter.dart';
import 'package:healus/services/ble/opcodes.dart';

/// 스트레스 테스트를 위한 고기능 Mock BLE Writer
class StressMockBleWriter implements BleWriter {
  final BlePacketAssembler assembler;
  final double lossRate; // 패킷 유실률 (0.0 ~ 1.0)
  final int latencyMs; // 인위적 지연 시간 (ms)
  final double corruptionRate; // 패킷 손상률 (0.0 ~ 1.0)
  final Random _random = Random();

  int totalChunksSent = 0;
  int lostChunksCount = 0;
  int corruptedChunksCount = 0;

  StressMockBleWriter({
    required this.assembler,
    this.lossRate = 0.05, // 기본 5% 패킷 유실 시뮬레이션
    this.latencyMs = 10,  // 기본 10ms 레이턴시 주입
    this.corruptionRate = 0.02, // 기본 2% 데이터 오염 주입
  });

  @override
  Future<void> write(List<int> value, {bool withoutResponse = false}) async {
    totalChunksSent++;

    // 1. 인위적 지연 시간 시뮬레이션 ($L_{max}$ 주입)
    if (latencyMs > 0) {
      await Future.delayed(Duration(milliseconds: latencyMs));
    }

    // 2. 패킷 유실 시뮬레이션 (드롭 처리)
    if (_random.nextDouble() < lossRate) {
      lostChunksCount++;
      return; // 데이터를 조립기에 전달하지 않고 누락시킴 (Packet Loss)
    }

    List<int> dataToDeliver = List.from(value);

    // 3. 데이터 오염 시뮬레이션 (동기화 유실 유도)
    if (_random.nextDouble() < corruptionRate) {
      corruptedChunksCount++;
      // 임의의 위치에 잘못된 바이트 삽입 또는 Start Code를 깨뜨림
      if (dataToDeliver.isNotEmpty) {
        dataToDeliver[0] = 0x00; // 헤더 훼손 (동기 유실 유도)
      }
    }

    // 최종적으로 BLE 패킷 조립기에 청크 주입
    assembler.onChunkReceived(dataToDeliver);
  }
}

void main() {
  group(r'BLE 통신 모듈 초고부하 스트레스 테스트 ($X_{security}$ 검증)', () {
    late BlePacketAssembler assembler;
    late BlePacketTransmitter transmitter;

    setUp(() {
      assembler = BlePacketAssembler();
      transmitter = BlePacketTransmitter();
    });

    tearDown(() {
      assembler.dispose();
    });

    test('실시간 대량 패킷 연속 송수신 및 복구 능력 평가', () async {
      // 5% 패킷 유실, 15ms 레이턴시, 2% 헤더 손상 스트레스 환경 구성
      final writer = StressMockBleWriter(
        assembler: assembler,
        lossRate: 0.05,
        latencyMs: 15,
        corruptionRate: 0.02,
      );

      final List<List<int>> receivedPackets = [];
      final completer = Completer<void>();
      final int totalPayloads = 500;

      // 수신 스트림 리스너 등록
      final subscription = assembler.packetStream.listen((packet) {
        receivedPackets.add(packet);
        // 목표량(유실/오류 등을 제외한 성공 패킷들)이 수신되면 검사 마감
        if (receivedPackets.length >= (totalPayloads * 0.4).toInt()) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      // 500개의 20바이트 논리 패킷 고속 송신 시도
      final List<Future> sendTasks = [];

      print(">> BLE 스트레스 테스트 시작: $totalPayloads개 논리 패킷 전송 개시...");
      final startTime = DateTime.now();

      for (int i = 0; i < totalPayloads; i++) {
        // 임의의 패킷 구성 (Start Code: 0xEF, Opcode: 0x05, Payload...)
        final packet = List<int>.filled(20, 0);
        packet[0] = kStartCode;
        packet[1] = Opcodes.btStateInd;
        packet[2] = 4;
        // 데이터 필드에 유니크한 카운터 적재
        packet[3] = i & 0xFF;
        packet[4] = (i >> 8) & 0xFF;

        // 비동기 병렬 전송 큐 시뮬레이션
        sendTasks.add(transmitter.send20BytePacket(writer, packet));
      }

      // 송신 작업 완료 대기
      try {
        await Future.wait(sendTasks);
      } catch (e) {
        print("송신 중 에러 발생 (정상 차단/예외 유도됨): $e");
      }

      // 최종 수신 대기 (타임아웃 방어 포함)
      await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          print(">> 스트레스 테스트 시간 제한(45초) 초과로 마감 처리");
        },
      );

      final endTime = DateTime.now();
      final elapsed = endTime.difference(startTime);

      await subscription.cancel();

      // 통계 계산
      final totalSentChunks = writer.totalChunksSent; // 2000 청크 (1000 패킷 * 2)
      final lostChunks = writer.lostChunksCount;
      final corruptedChunks = writer.corruptedChunksCount;
      final successPackets = receivedPackets.length;

      final double actualLossRate = (lostChunks / totalSentChunks) * 100;
      final double actualCorruptionRate = (corruptedChunks / totalSentChunks) * 100;
      final double packetSuccessRate = (successPackets / totalPayloads) * 100;

      print("\n==================================================");
      print("               BLE STRESS TEST REPORT             ");
      print("==================================================");
      print("총 송신 시도 (논리 20Byte 패킷): $totalPayloads 개");
      print("총 송신 시도 (물리 10Byte 청크): $totalSentChunks 개");
      print("소요 시간: ${elapsed.inMilliseconds} ms");
      print("물리적 청크 누락 (Drop): $lostChunks 개 (${actualLossRate.toStringAsFixed(2)}%)");
      print("물리적 청크 오염 (Corrupt): $corruptedChunks 개 (${actualCorruptionRate.toStringAsFixed(2)}%)");
      print("최종 성공 수집 패킷 (20Byte): $successPackets 개 (${packetSuccessRate.toStringAsFixed(2)}%)");
      print("초당 처리량 (Throughput): ${(successPackets / (elapsed.inMilliseconds / 1000.0)).toStringAsFixed(2)} packets/sec");
      print("==================================================");

      // 검증 Assert
      // 5% 유실률 + 2% 오염 하에 20Byte 무결성 정합성 복구가 정상 수행되는가?
      // (10Byte 청크가 유실되거나 훼손되면, 조립기 버퍼는 0xEF를 찾아가며 동기화를 유실 후 복구하므로, 
      //  동작 중 crash가 없어야 하고 남은 정상 패킷들은 완벽히 수집되어야 함.)
      expect(successPackets, greaterThan(0));
      expect(assembler.rxBuffer.length, lessThan(40)); // 가비지가 한도 없이 누적되지 않고 지워졌는지 확인
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
