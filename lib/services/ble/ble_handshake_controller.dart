import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ble_service_interface.dart';
import 'ble_service_provider.dart';
import 'opcodes.dart';
import 'packet_parser.dart';
import '../../state/pump_state_provider.dart';
import 'ble_mutex.dart';

/// BLE 연결 및 기기 핸드셰이크 단계를 수행하는 상태 클래스
class BleHandshakeState {
  final bool isConnecting;
  final bool isHandshaking;
  final String? error;
  final bool isSuccess;

  BleHandshakeState({
    this.isConnecting = false,
    this.isHandshaking = false,
    this.error,
    this.isSuccess = false,
  });

  BleHandshakeState copyWith({
    bool? isConnecting,
    bool? isHandshaking,
    String? error,
    bool? isSuccess,
  }) {
    return BleHandshakeState(
      isConnecting: isConnecting ?? this.isConnecting,
      isHandshaking: isHandshaking ?? this.isHandshaking,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// BLE 기기와의 세션 체결 및 유효성 검증을 담당하는 핸드셰이크 컨트롤러
class BleHandshakeController extends StateNotifier<BleHandshakeState> {
  final Ref _ref;

  BleHandshakeController(this._ref) : super(BleHandshakeState());

  /// 상태를 초기화하여 이전 연결 성공(isSuccess=true) 등 캐시된 값을 정리합니다.
  void reset() {
    state = BleHandshakeState();
  }

  /// 특정 MAC 주소를 가진 인슐린펌프 기기에 연결하고 규격서 사양의 세션을 시작합니다.
  Future<bool> connectAndHandshake(String macAddress) async {
    state = BleHandshakeState(isConnecting: true);

    final isTest = _ref.read(testModeProvider);
    if (isTest) {
      // 이미 테스트 모드인 경우 Mock BLE 서비스가 내부에서 세션을 자동 충족하므로 통과
      state = BleHandshakeState(isSuccess: true);
      return true;
    }

    int attempt = 1;
    bool connected = false;
    final bleService = _ref.read(bleServiceProvider);

    // 1. BLE 실제 연결 시도 (최대 누적 대기시간 15초 타임아웃, 1회 재시도 포함 - Hold 플래그 확인)
    final bypassHold = _ref.read(timeoutHoldProvider);
    final connectTimeout = bypassHold ? const Duration(days: 365) : const Duration(seconds: 15);
    String lastError = "알 수 없는 오류";
    while (attempt <= 2 && !connected) {
      try {
        print("BLE 연결 시도 ($attempt/2)... MAC: $macAddress");
        await bleService.connect(macAddress).timeout(connectTimeout);
        connected = true;
        break;
      } catch (e) {
        lastError = e.toString();
        print("BLE 연결 실패 (시도 $attempt): $e");
        if (bypassHold) {
          // 홀드 상태이면 재시도 횟수 제한 없이 연결될 때까지 계속 기다림
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        attempt++;
        if (attempt <= 2) {
          // 재시도 전 대기 마진
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    if (!connected) {
      _enterTestMode("15초 초과 BLE 연결 실패 및 재시도 실패: $lastError");
      if (kReleaseMode) {
        throw Exception("[V12 최신빌드] 연결 실패: $lastError\n(장비 절전 모드 또는 블루투스 오류)");
      }
      return true;
    }

    return await executeHandshakeOnly();
  }

  /// 이미 물리적으로 연결된 상태에서 핸드셰이크 절차만 단독으로 수행합니다 (백그라운드 자동 재연결 용).
  Future<bool> executeHandshakeOnly() async {
    final bleService = _ref.read(bleServiceProvider);
    
    // 2. BLE 핸드셰이킹 시나리오 수행
    state = state.copyWith(isConnecting: false, isHandshaking: true);
    
    final mutex = _ref.read(bleMutexProvider);

    try {
      // 2.1 BT_CONNECTABLE_CTRL_REQ (0x02) 송신 (앱 -> 기기가 먼저 말 걸기)
      print("핸드셰이크: BT_CONNECTABLE_CTRL_REQ (0x02) 송신");
      final connectReqPacket = List<int>.filled(20, 0);
      connectReqPacket[0] = kStartCode;
      connectReqPacket[1] = Opcodes.btConnectableCtrlReq;
      connectReqPacket[2] = 0;
      
      await mutex.acquire();
      try {
        await bleService.sendPacket(connectReqPacket);

        // 2.2 BT_START_REQ (0x01) 수신 대기 (기기가 응답)
        print("핸드셰이크: BT_START_REQ (0x01) 대기 중...");
        try {
          await _waitForPacket(bleService, Opcodes.btStartReq, timeout: const Duration(seconds: 4));
        } catch (e) {
          print("핸드셰이크: 0x01 대기 실패 (무시하고 계속 진행): $e");
        }

        // 2.3 (안전) 0x02 명령에 대한 ACK (0x00) 대기
        print("핸드셰이크: BT_CONNECTABLE_CTRL_REQ 응답 ACK (0x00) 대기 중...");
        try {
          await _waitForPacket(bleService, Opcodes.btMsgRes, timeout: const Duration(seconds: 2));
        } catch (e) {
          print("핸드셰이크: 0x00 ACK 대기 실패 (무시하고 계속 진행): $e");
        }
      } finally {
        mutex.release();
      }

      // 2.3 기기 상태 조회 부분은 앱 정책 변경으로 인해 제거됨.

      // 3. 시간 동기화 (기존 코드 제거됨, 대시보드 진입 시 수행하도록 이동)


      // 2.5 현재 기기 비밀번호 조회 (BT_PRS_APP_PASSWD_REQ -> BT_PRS_APP_PASSWD_RES)
      print("핸드셰이크: 현재 비밀번호 조회 - BT_PRS_APP_PASSWD_REQ (0x41) 송신");
      final passwdReqPacket = List<int>.filled(20, 0);
      passwdReqPacket[0] = kStartCode;
      passwdReqPacket[1] = Opcodes.btPrsAppPasswdReq;
      passwdReqPacket[2] = 0;
      
      await mutex.acquire();
      List<int>? passwdResPacket;
      try {
        await bleService.sendPacket(passwdReqPacket);
        passwdResPacket = await _waitForPacket(bleService, Opcodes.btNewAppPasswdInd, timeout: const Duration(seconds: 3));
      } finally {
        mutex.release();
      }
      
      final passwdBytes = passwdResPacket.sublist(3, 9);
      // 펌프는 비밀번호를 ASCII가 아닌 순수 숫자(0~9) 배열로 보냄 (예: [1,1,1,1,1,1])
      final passwordStr = passwdBytes.map((b) => b.toString()).join('');

      // 수신된 비밀번호 전역 상태에 주입 저장
      _ref.read(pumpStateProvider.notifier).setPasswordForce(passwordStr.isNotEmpty ? passwordStr : "000000");

      print("핸드셰이크 최종 성공! 비밀번호 동기화 완료: $passwordStr");
      state = BleHandshakeState(isSuccess: true);
      return true;
    } catch (e) {
      print("BLE 핸드셰이크 실패: $e");
      await bleService.disconnect();
      _enterTestMode("핸드셰이크 실패로 테스트 모드 진입: $e");
      
      if (kReleaseMode) {
        // 상용 빌드에서는 테스트 모드로 넘어가지 않으므로, 실패 사유를 UI로 전달하기 위해 예외를 다시 던집니다.
        throw Exception("[V19] 핸드셰이크 실패: $e");
      }
      return true;
    }
  }

  /// 실패 및 타임아웃 발생 시 테스트 모드로 대체 복구 진입 처리
  void _enterTestMode(String reason) {
    if (kReleaseMode) {
      print("연결/핸드셰이크 실패: $reason -> 상용 빌드이므로 테스트 모드로 진입하지 않습니다.");
      state = BleHandshakeState(isSuccess: false);
      return;
    }
    print("연결/핸드셰이크 실패 원인: $reason -> 가상 테스트 모드로 진입합니다.");
    _ref.read(testModeProvider.notifier).state = true;
    
    // 테스트 모드 진입 시 기존 비밀번호가 없거나 기본값일 경우에만 기본 비밀번호 "000000" 설정
    final currentPassword = _ref.read(pumpStateProvider).password;
    if (currentPassword == "000000" || currentPassword.isEmpty) {
      _ref.read(pumpStateProvider.notifier).setPasswordForce("000000");
    }
    
    state = BleHandshakeState(isSuccess: true);
  }

  /// 특정 Opcode의 20Byte 패킷이 수신될 때까지 비동기로 대기 (Hold 플래그 확인)
  Future<List<int>> _waitForPacket(BleService service, int opCode, {required Duration timeout}) {
    final completer = Completer<List<int>>();
    StreamSubscription? sub;
    sub = service.receivedPacketsStream.listen((packet) {
      if (packet[1] == opCode || (opCode == Opcodes.btPrsAppPasswdRes && packet[1] == Opcodes.btNewAppPasswdInd)) {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(packet);
        }
      }
    });

    final bypassHold = _ref.read(timeoutHoldProvider);
    final waitTimeout = bypassHold ? const Duration(days: 365) : timeout;

    return completer.future.timeout(waitTimeout, onTimeout: () {
      sub?.cancel();
      throw TimeoutException("메시지 응답(Opcode: 0x${opCode.toRadixString(16).toUpperCase()}) 대기 시간 초과");
    });
  }
}

/// BLE 핸드셰이크 컨트롤러 프로바이더
final bleHandshakeControllerProvider = StateNotifierProvider<BleHandshakeController, BleHandshakeState>((ref) {
  return BleHandshakeController(ref);
});
