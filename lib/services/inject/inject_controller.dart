import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/opcodes.dart';
import '../ble/packet_parser.dart';
import '../ble/ble_packet_transmitter.dart';
import '../ble/ble_service_provider.dart';
import 'package:flutter/material.dart';
import '../../globals.dart';
import '../ble/ble_mutex.dart';

/// BLE 전송 도구 프로바이더
final bleTransmitterProvider = Provider<BlePacketTransmitter>((ref) {
  return BlePacketTransmitter();
});

/// 인슐린 주입 제어 및 선점형 긴급 정지 큐를 관리하는 Controller
class InjectController extends StateNotifier<List<List<int>>> {
  final BlePacketTransmitter _transmitter;
  final Ref _ref;
  bool _isProcessing = false;

  InjectController(this._transmitter, this._ref) : super([]);

  /// 대기 중인 패킷 송신 큐의 복사본
  List<List<int>> get queue => List.unmodifiable(state);

  /// 일반 제어/조회 패킷을 송신 큐 맨 뒤에 삽입 (FIFO)
  void queuePacket(List<int> packet) {
    state = [...state, packet];
    _processQueue();
  }

  /// 긴급 정지와 같은 고순위 패킷을 큐의 맨 앞에 강제 삽입 (LIFO / Preemption)
  void queueEmergencyPacket(List<int> packet) {
    state = [packet, ...state];
    _processQueue();
  }

  /// 블루투스 연결 단절 시 큐에 남아있는 오염된 패킷들을 일괄 폐기합니다.
  void clearQueue() {
    print("[DEBUG] InjectController.clearQueue: 큐를 비웁니다. 폐기된 패킷 수: ${state.length}");
    state = [];
    _isProcessing = false;
  }

  /// 인슐린 주입 요청 (BT_INJ_REQ, 0x17)
  /// [injVal]: 주입할 인슐린 양 (Double Unit)
  /// [injSel]: 주입 유형 (0: 식사주입, 1: 추가주입)
  Future<bool> requestInjection(double injVal, int injSel) async {
    final packet = List<int>.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btInjReq;
    packet[2] = 3; // Data length
    packet[3] = injSel;

    // 의료 정밀도를 위한 x100 스케일링 정수 변환 (소수점 극복)
    final int scaledVal = (injVal * 100).round();
    PacketParser.writeUint16(packet, 4, scaledVal);

    print("[DEBUG] InjectController.requestInjection: val=$injVal, sel=$injSel, scaled=$scaledVal");
    return await checkStateAndExecute(packet);
  }

  /// 소프트웨어 최우선 긴급 정지 요청 (BT_INJ_STOP_REQ, 0x37)
  /// 이 명령은 대기 중인 모든 요청을 밀어내고 큐의 최선두(Preemption)로 진입합니다.
  void requestEmergencyStop() {
    final packet = List<int>.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btInjStopReq;
    packet[2] = 1; // Data length
    packet[3] = 0x01; // pause_state = TRUE (강제 정지 설정)

    print("[DEBUG] InjectController.requestEmergencyStop: queuing stop packet");
    queueEmergencyPacket(packet);
  }

  Future<bool> checkStateAndExecute(List<int> targetPacket) async {
    final bleService = _ref.read(bleServiceProvider);
    if (!bleService.isConnected) return false;

    final bypassHold = _ref.read(timeoutHoldProvider);
    final waitTimeout = bypassHold ? const Duration(days: 365) : const Duration(seconds: 3);

    final resCompleter = Completer<void>();
    final indCompleter = Completer<int>();
    StreamSubscription? sub;

    bool resReceived = false;

    sub = bleService.receivedPacketsStream.listen((packet) {
      if (!resReceived) {
        if (packet[1] == Opcodes.btMsgRes) { // 0x00
          resReceived = true;
          if (!resCompleter.isCompleted) resCompleter.complete();
        }
      } else {
        if (packet[1] == Opcodes.btStateInd) { // 0x05
          sub?.cancel();
          if (!indCompleter.isCompleted) indCompleter.complete(packet[3]);
        }
      }
    });

    try {
      print("[DEBUG] checkStateAndExecute: 0x04 (BT_STATE_REQ) 송신");
      final stateReqPacket = List<int>.filled(20, 0);
      stateReqPacket[0] = kStartCode;
      stateReqPacket[1] = Opcodes.btStateReq;
      stateReqPacket[2] = 0;
      await bleService.sendPacket(stateReqPacket);

      // Timeout 적용 대기
      await Future.wait([resCompleter.future, indCompleter.future]).timeout(waitTimeout);

      final stateVal = await indCompleter.future;

      if (stateVal == 0x01) {
        print("[DEBUG] checkStateAndExecute: 기기가 idle 상태(0x01)임. 패킷 송신 진행");
        queuePacket(targetPacket);
        return true;
      } else {
        print("[DEBUG] checkStateAndExecute: 기기가 idle이 아님($stateVal). 주입 취소");
        return false;
      }
    } on TimeoutException {
      sub?.cancel();
      print("[DEBUG] checkStateAndExecute: 상태 응답 타임아웃. 주입 취소");
      return false;
    } catch (e) {
      sub?.cancel();
      print("[DEBUG] checkStateAndExecute: 오류 - $e");
      return false;
    } finally {
      sub?.cancel();
    }
  }

  /// 비동기 전송 큐 처리 루프
  Future<void> _processQueue() async {
    if (_isProcessing) {
      print("[DEBUG] InjectController._processQueue: already processing queue");
      return;
    }
    _isProcessing = true;

    final bleService = _ref.read(bleServiceProvider);
    final mutex = _ref.read(bleMutexProvider);

    print("[DEBUG] InjectController._processQueue: starting loop. Queue size=${state.length}, isConnected=${bleService.isConnected}");

    while (state.isNotEmpty) {
      if (!bleService.isConnected) {
        // 기기가 아직 연결되지 않은 상태이면 대기를 멈추고 큐를 유지
        print("[DEBUG] InjectController._processQueue: BLE service is not connected. Pausing queue processing.");
        _isProcessing = false;
        return;
      }

      final currentPacket = state.first;
      // 큐에서 패킷 꺼내기
      state = state.sublist(1);

      await mutex.acquire();
      try {
        print("[DEBUG] InjectController._processQueue: sending packet opcode=0x${currentPacket[1].toRadixString(16)}");
        
        final expectedOpcode = _getExpectedResponse(currentPacket[1]);
        final ackCompleter = Completer<void>();
        StreamSubscription? sub;
        
        bool received00 = false;
        bool receivedExpected = false;
        
        sub = bleService.receivedPacketsStream.listen((packet) {
          // 0x00 (BT_MSG_RES) 응답 확인
          if (packet[1] == Opcodes.btMsgRes && packet[3] == currentPacket[1]) {
            if (packet[4] == 0x00) {
              received00 = true;
            } else {
              // 에러 응답 수신 시 무한 대기 방지를 위해 큐 즉시 해제
              if (!ackCompleter.isCompleted) {
                print("[WARN] Received error 0x${packet[4].toRadixString(16)} for opcode 0x${currentPacket[1].toRadixString(16)}");
                ackCompleter.complete();
              }
              return;
            }
          }
          
          if (packet[1] == expectedOpcode) {
            if (expectedOpcode == Opcodes.btBaseValueRes) {
              // 기초 설정 값(0x2F -> 0x30) 요청의 경우 3번째 byte(time_param)가 0x03일 때 완료 처리
              if (packet.length >= 4 && packet[3] == 0x03) {
                receivedExpected = true;
              }
            } else {
              receivedExpected = true;
            }
          }
          
          // 완료 조건 검사
          bool conditionMet = false;
          if (currentPacket[1] == Opcodes.btTimeBaseSetReq) {
            // [수정사항] 0x0F의 경우 반드시 0x00(정상)과 0x12(설정응답)를 모두 수신해야 완료로 판단함
            conditionMet = received00 && receivedExpected;
          } else {
            conditionMet = receivedExpected;
          }

          if (conditionMet && !ackCompleter.isCompleted) {
            ackCompleter.complete();
          }
        });

        await bleService.sendPacket(currentPacket);
        
        // Timeout 적용 대기 (기초설정 0x0F는 플래시 기록 마진 등을 위해 20초, 그 외 모든 일반 명령어는 20초로 연장)
        final bypassHold = _ref.read(timeoutHoldProvider);
        final waitTimeout = bypassHold 
            ? const Duration(days: 365) 
            : const Duration(seconds: 20);
        
        try {
          await ackCompleter.future.timeout(waitTimeout);
          print("[DEBUG] InjectController._processQueue: packet sent and expected response (0x${expectedOpcode.toRadixString(16)}) received");
        } on TimeoutException {
          print("[WARN] InjectController._processQueue: Response timeout for opcode=0x${currentPacket[1].toRadixString(16)}");
        } finally {
          sub.cancel();
        }
        
      } catch (e) {
        // 오류 로그 기록 처리 (현업 수준의 예외 방어)
        print("BLE 패킷 전송 오류 발생: $e");
      } finally {
        mutex.release();
      }
    }

    print("[DEBUG] InjectController._processQueue: loop finished");
    _isProcessing = false;
  }

  /// 송신된 Opcode에 따라 기대되는 응답(Response/Indication) Opcode를 반환합니다.
  int _getExpectedResponse(int requestOpcode) {
    switch (requestOpcode) {
      case Opcodes.btCurTimeInd: return Opcodes.btCurTimeRes; // 0x06 -> 0x44
      case Opcodes.btBattDataReq: return Opcodes.btBattDataRes; // 0x70 -> 0x72
      case Opcodes.btPumpPidReq: return Opcodes.btPumpPidRes; // 0x09 -> 0x0A
      case Opcodes.btPumpFwReq: return Opcodes.btPumpFwRes; // 0x3E -> 0x3F
      case Opcodes.btPrsAppPasswdReq: return Opcodes.btPrsAppPasswdRes; // 0x41 -> 0x3D
      case Opcodes.btPrsAppPasswdInd: return Opcodes.btNewAppPasswdInd; // 0x3C -> 0x42
      case Opcodes.btStateReq: return Opcodes.btStateInd; // 0x04 -> 0x05
      case Opcodes.btLogInjQntReq: return Opcodes.btLogInjQntInd; // 0x1E -> 0x1F
      case Opcodes.btEatValueReq: return Opcodes.btEatValueRes; // 0x2D -> 0x2E
      case Opcodes.btBaseValueReq: return Opcodes.btBaseValueRes; // 0x2F -> 0x30
      case Opcodes.btTimeBaseSetReq: return Opcodes.btSetRes; // 0x0F -> 0x12
      case Opcodes.btMealSetReq: return Opcodes.btSetRes; // 0x10 -> 0x12
      case Opcodes.btInjInfoReq: return Opcodes.btInjInfoRes; // 0x15 -> 0x16
      default: return Opcodes.btMsgRes; // 기본적으로 0x00을 기다림
    }
  }
}

/// 전역 주입 제어기 프로바이더
final injectControllerProvider = StateNotifierProvider<InjectController, List<List<int>>>((ref) {
  final transmitter = ref.read(bleTransmitterProvider);
  return InjectController(transmitter, ref);
});
