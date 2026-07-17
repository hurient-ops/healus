import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_service_interface.dart';
import 'ble_packet_assembler.dart';
import 'ble_packet_transmitter.dart';
import 'opcodes.dart';

/// 실제 인슐린 펌프 디바이스와 통신하는 물리 BLE 서비스 구현체
class HardwareBleService implements BleService {
  @override
  void Function(List<int>)? onPacketSent;

  final BlePacketTransmitter _transmitter = BlePacketTransmitter();
  late final BlePacketAssembler _assembler;

  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  final StreamController<List<int>> _receivedPacketsController = StreamController<List<int>>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  StreamSubscription? _connectionStateSub;
  StreamSubscription? _notifySub;

  bool _isConnected = false;
  bool _isTestMode = false;
  bool _isConnecting = false;
  bool _bypassTimeoutHold = false;

  /// 서비스 UUID 및 캐릭터리스틱  // --- [업데이트] 기기에서 발견된 실제 하드웨어 UUID ---
  final Guid serviceUuid = Guid("739298b6-87b6-4984-a5dc-bdc18b068985");
  // 캐릭터리스틱 UUID는 동적으로 탐색합니다.
  final Guid writeUuid = Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // 더 이상 강제 사용 안 함
  final Guid readUuid = Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");  // 더 이상 강제 사용 안 함

  HardwareBleService() {
    _assembler = BlePacketAssembler(
      onTimeoutReconnect: _handleReassemblyTimeout,
    );
    _assembler.packetStream.listen((packet) {
      _receivedPacketsController.add(packet);
    });
  }

  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  @override
  Stream<List<int>> get receivedPacketsStream => _receivedPacketsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isTestMode => _isTestMode;

  @override
  void setTestMode(bool testMode) {
    _isTestMode = testMode;
  }

  @override
  void setBypassTimeoutHold(bool hold) {
    _bypassTimeoutHold = hold;
    _assembler.bypassTimeoutHold = hold;
  }

  /// 500ms 재조립 타임아웃 발생 시 자동 호출되는 복구 메커니즘
  void _handleReassemblyTimeout() async {
    print("BLE 재조립 타임아웃 500ms 만료 - 연결 복구를 시작합니다.");
    if (_device != null) {
      await disconnect();
      // 재연결 시도
      try {
        await connect(_device!.remoteId.str).timeout(const Duration(seconds: 3));
      } catch (e) {
        print("재조립 타임아웃 복구 재연결 실패: $e -> 테스트 모드 전환 필요");
        // 상위에 에러 인계 또는 연결해제 전파
        _connectionStateController.add(false);
      }
    }
  }

  @override
  Future<void> connect(String macAddress) async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;

    final deviceId = DeviceIdentifier(macAddress);
    _device = BluetoothDevice.fromId(deviceId.str);

    final stopwatch = Stopwatch()..start();

    try {
      // 기존 연결이 혹시 꼬여있을 수 있으므로 안전하게 연결 해제 시도
      try {
        await _device!.disconnect();
      } catch (_) {}

      // 1. 최대 누적 대기시간 15초 타임아웃 설정 (Hold 플래그 확인)
      // 실제 BLE 통신 환경에서는 기기 스캔 및 서비스 디스커버리 등에서 3초 이상이 소요되는 경우가 많으므로 넉넉하게 15초 부여
      final connectTimeout = _bypassTimeoutHold ? const Duration(days: 365) : const Duration(seconds: 15);
      await _device!.connect(timeout: connectTimeout, autoConnect: false).timeout(
        connectTimeout,
        onTimeout: () {
          throw TimeoutException("BLE 연결 대기 시간을 초과하였습니다.");
        },
      );

      // 2. 서비스 검색
      List<BluetoothService> services = await _device!.discoverServices();
      BluetoothService? targetService;
      List<String> foundUuids = [];
      for (var s in services) {
        foundUuids.add(s.uuid.toString());
        if (s.uuid == serviceUuid) {
          targetService = s;
          break;
        }
      }

      if (targetService == null) {
        String uuidListStr = foundUuids.join(",\n");
        throw Exception("HealUs 통신 서비스를 찾을 수 없습니다.\n발견된 서비스 목록:\n$uuidListStr");
      }

      // 3. 캐릭터리스틱 획득 (속성 기반 자동 탐지 및 분석용 덤프)
      List<String> charUuids = [];
      for (var c in targetService.characteristics) {
        charUuids.add("${c.uuid.toString().substring(0, 8)}.. (W:${c.properties.write}, N:${c.properties.notify})");
        if (c.properties.write || c.properties.writeWithoutResponse) {
          _writeCharacteristic = c;
        }
        if (c.properties.notify || c.properties.indicate) {
          _readCharacteristic = c;
        }
      }

      if (_writeCharacteristic == null || _readCharacteristic == null) {
        String charListStr = charUuids.join("\n");
        throw Exception("송수신 캐릭터리스틱이 누락되었습니다.\n발견된 캐릭터리스틱:\n$charListStr");
      }

      // 4. Notification 구독 활성화
      await _readCharacteristic!.setNotifyValue(true);
      _notifySub = _readCharacteristic!.onValueReceived.listen((bytes) {
        // 물리 10Byte 청크가 도착할 때마다 조립기에 투입
        _assembler.onChunkReceived(bytes);
      });

      // 5. 연결 모니터링 설정
      _connectionStateSub = _device!.connectionState.listen((state) {
        final connected = state == BluetoothConnectionState.connected;
        if (_isConnected != connected) {
          _isConnected = connected;
          _connectionStateController.add(connected);
        }
      });

      _isConnected = true;
      _connectionStateController.add(true);
      print("HealUs 기기 연결 성공: $macAddress");
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(false);
      throw Exception("[V19] 에러: $e\n(장비 절전 모드 또는 블루투스 오류)");
    } finally {
      stopwatch.stop();
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    _notifySub?.cancel();
    _connectionStateSub?.cancel();
    _notifySub = null;
    _connectionStateSub = null;

    if (_device != null) {
      await _device!.disconnect();
    }

    _isConnected = false;
    _connectionStateController.add(false);
    print("BLE 연결이 강제 해제되었습니다.");
  }

  @override
  Future<void> sendPacket(List<int> packet) async {
    final char = _writeCharacteristic;
    if (char == null || !_isConnected) {
      throw StateError("연결된 기기가 없어 패킷을 송신할 수 없습니다.");
    }

    final writer = CharacteristicWriter(char);
    // 75ms 마진 전송기 작동
    await _transmitter.send20BytePacket(writer, packet);
    onPacketSent?.call(packet);
  }

  @override
  Future<void> setPauseState(bool pause) async {
    final List<int> packet = List.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btStopCtrlReq;
    packet[2] = 1;
    packet[3] = pause ? 1 : 0;
    
    print("Hardware BLE 서비스: 일시정지 제어 패킷 전송 (pause = $pause)");
    await sendPacket(packet);
  }

  @override
  Future<void> resetDevice() async {
    final List<int> packet = List.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btSystemReset;
    packet[2] = 0;
    
    print("Hardware BLE 서비스: 시스템 리셋 패킷 전송 (연결 유지)");
    try {
      await sendPacket(packet);
    } catch (e) {
      print("리셋 패킷 전송 중 오류 발생: $e");
    }
  }
}
