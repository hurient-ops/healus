import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_service_interface.dart';
import 'hardware_ble_service.dart';
import 'mock_ble_service.dart';

/// 전역 테스트 모드 상태 프로바이더 (true: 가상 테스트 모드 활성, false: 물리 연결 시도)
final testModeProvider = StateProvider<bool>((ref) {
  return false;
});

/// 수동 디버깅 시 타임아웃을 일시 정지(Hold)하는 플래그 프로바이더
final timeoutHoldProvider = StateProvider<bool>((ref) {
  return false;
});

/// 최근 수신한 패킷의 이력 로그 프로바이더
final receivedPacketsLogProvider = StateProvider<List<String>>((ref) {
  return [];
});

/// 최근 송신한 패킷의 이력 로그 프로바이더
final sentPacketsLogProvider = StateProvider<List<String>>((ref) {
  return [];
});

/// BLE 서비스를 프록시하고 동적으로 스위칭하는 매니저 클래스
class BleServiceManager implements BleService {
  final Ref _ref;
  late BleService _currentService;

  @override
  void Function(List<int>)? onPacketSent;
  
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  final StreamController<List<int>> _receivedPacketsController = StreamController<List<int>>.broadcast();
  
  StreamSubscription? _connectionSub;
  StreamSubscription? _packetsSub;
  bool _isReconnecting = false;
  String? _savedMacAddress;
  String? get savedMacAddress => _savedMacAddress;

  BleServiceManager(this._ref) {
    // 최초 상태 로드
    updateService(_ref.read(testModeProvider));
  }

  void _handlePacketReceived(List<int> packet) {
    // 수신 패킷 이력 로그에 포맷팅하여 추가
    final hexStr = packet.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final logMsg = "[$timestamp] <- 0x$hexStr";

    final currentLogs = _ref.read(receivedPacketsLogProvider);
    _ref.read(receivedPacketsLogProvider.notifier).state = [logMsg, ...currentLogs].take(1000).toList();
  }

  void _handlePacketSent(List<int> packet) {
    // 송신 패킷 이력 로그에 포맷팅하여 추가
    final hexStr = packet.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final logMsg = "[$timestamp] -> 0x$hexStr";

    final currentLogs = _ref.read(sentPacketsLogProvider);
    _ref.read(sentPacketsLogProvider.notifier).state = [logMsg, ...currentLogs].take(1000).toList();

    // 외부로 전파
    onPacketSent?.call(packet);
  }

  void updateService(bool isTestMode) {
    print("[DEBUG] BleServiceManager.updateService: switching to isTestMode=$isTestMode");
    _connectionSub?.cancel();
    _packetsSub?.cancel();

    if (isTestMode) {
      final mock = MockBleService();
      mock.onPacketSent = _handlePacketSent;
      _currentService = mock;
      
      // 연결 상태 및 패킷 스트림 포워딩 설정
      _connectionSub = mock.connectionStateStream.listen((connected) {
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(connected);
        }
      });

      _packetsSub = mock.receivedPacketsStream.listen((packet) {
        _handlePacketReceived(packet);
        _receivedPacketsController.add(packet);
      });

      // Mock BLE 연결 활성화
      mock.connect("");
    } else {
      final hw = HardwareBleService();
      hw.onPacketSent = _handlePacketSent;
      _currentService = hw;

      _connectionSub = hw.connectionStateStream.listen((connected) {
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(connected);
        }
        
        // 비정상 단절 시 재연결 루프 (사용자 명시적 해제가 아닌 경우)
        if (!connected && _savedMacAddress != null) {
          if (_isReconnecting) {
            print("BLE 자동 재연결 루프가 이미 동작 중입니다. 중복 실행 방지.");
          } else {
            print("비정상 BLE 연결 단절 감지 - 백그라운드 무한 대기 자동 재연결 가동");
            _isReconnecting = true;
            () async {
              while (!hw.isConnected && _savedMacAddress != null && _isReconnecting) {
                try {
                  print("BLE 자동 재연결 (OS Background) 대기 중... ($_savedMacAddress)");
                  // 안드로이드 OS 자체의 Background Daemon 에 백업(autoConnect: true)을 맡겨 무한 대기
                  await hw.connect(_savedMacAddress!, autoConnect: true);
                  
                  if (hw.isConnected) {
                    print("BLE 자동 재연결 성공!");
                    break;
                  }
                } catch (e) {
                  print("BLE 자동 재연결 에러, 5초 후 재시도: $e");
                  await Future.delayed(const Duration(seconds: 5));
                }
              }
              _isReconnecting = false;
            }();
          }
        }
      });

      _packetsSub = hw.receivedPacketsStream.listen((packet) {
        _handlePacketReceived(packet);
        if (!_receivedPacketsController.isClosed) {
          _receivedPacketsController.add(packet);
        }
      });
    }

    // 현재 홀드 상태 주입
    final holdVal = _ref.read(timeoutHoldProvider);
    _currentService.setBypassTimeoutHold(holdVal);
  }

  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  @override
  Stream<List<int>> get receivedPacketsStream => _receivedPacketsController.stream;

  @override
  bool get isConnected => _currentService.isConnected;

  @override
  bool get isTestMode => _currentService.isTestMode;

  @override
  Future<void> connect(String macAddress, {bool autoConnect = false}) async {
    _savedMacAddress = macAddress;
    await _currentService.connect(macAddress, autoConnect: autoConnect);
    // 연결 성공 시 영구 저장소에 식별자 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_ble_mac', macAddress);
  }

  @override
  Future<bool> scanForDevice(String macAddress) async {
    _savedMacAddress = macAddress;
    bool found = await _currentService.scanForDevice(macAddress);
    return found;
  }

  @override
  Future<void> disconnect() async {
    _savedMacAddress = null;
    _isReconnecting = false;
    if (!isTestMode) {
      await _currentService.disconnect();
    } else {
      print("[DEBUG] BleServiceManager.disconnect: ignored disconnect call because we are in test mode");
    }
  }

  /// 사용자가 설정 화면에서 명시적으로 연결을 끊을 때 호출하는 메서드
  Future<void> manualDisconnect() async {
    print("사용자 명시적 BLE 연결 해제 요청");
    _savedMacAddress = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_ble_mac');
    
    await disconnect();
  }

  @override
  Future<void> sendPacket(List<int> packet) async {
    await _currentService.sendPacket(packet);
  }

  @override
  void setTestMode(bool testMode) {
    _ref.read(testModeProvider.notifier).state = testMode;
  }

  @override
  void setBypassTimeoutHold(bool hold) {
    _currentService.setBypassTimeoutHold(hold);
  }

  /// === [TEST MODE ONLY] ===
  /// 가상 MockBleService의 주입 완료 패킷 트리거를 포워딩합니다.
  void fireFakeStopPacket() {
    if (_currentService is MockBleService) {
      (_currentService as MockBleService).fireFakeStopPacket();
    }
  }

  /// 수동으로 패킷 바이트를 직접 타이핑하여 스트림에 주입하는 디버그용 API
  void injectPacket(List<int> packet) {
    print("[DEBUG] BleServiceManager.injectPacket: injecting packet=0x${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
    if (!_receivedPacketsController.isClosed) {
      _receivedPacketsController.add(packet);
    }
  }

  void dispose() {
    _connectionSub?.cancel();
    _packetsSub?.cancel();
    _isReconnecting = false;
    _connectionStateController.close();
    _receivedPacketsController.close();
  }

  @override
  Future<void> setPauseState(bool pause) async {
    await _currentService.setPauseState(pause);
  }

  @override
  Future<void> resetDevice() async {
    await _currentService.resetDevice();
  }
}

/// 현재 활성화된 BLE 통신 서비스 프로바이더
final bleServiceProvider = Provider<BleService>((ref) {
  final manager = BleServiceManager(ref);
  
  // testModeProvider의 변경사항 감지 및 내부 서비스 스위칭을 Riverpod 컨텍스트에서 수행
  ref.listen<bool>(testModeProvider, (previous, next) {
    print("[DEBUG] bleServiceProvider listener: testModeProvider changed from $previous to $next");
    if (previous != next) {
      manager.updateService(next ?? false);
    }
  });

  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});

