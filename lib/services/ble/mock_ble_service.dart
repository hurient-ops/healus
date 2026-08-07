import 'dart:async';
import 'ble_service_interface.dart';
import 'opcodes.dart';
import 'packet_parser.dart';
import '../api/cloud_sync_service.dart';

/// 기기 없이 시나리오 테스트를 수행하는 가상 Mock BLE 서비스 구현체
class MockBleService implements BleService {
  @override
  void Function(List<int>)? onPacketSent;

  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  final StreamController<List<int>> _receivedPacketsController = StreamController<List<int>>.broadcast();

  bool _isConnected = false;
  bool _isTestMode = true;
  Timer? _injectionTimer;
  bool _isPaused = false;

  // 가상 기기 정보 상태 데이터
  String _password = "000000";
  int _batteryLevel = 4; // 100%
  int _insulinRemain = 30000; // 300.0U (Scale x100)
  final List<double> _basalRates = List.filled(24, 0.00);
  final Map<String, double> _mealSettings = {
    'breakfast': 1.00,
    'lunch': 1.00,
    'dinner': 1.00,
  };

  // 금일 주입량 모의 상태 변수
  double _basalSum = 0.00;
  double _morningSum = 0.00;
  double _lunchSum = 0.00;
  double _eveningSum = 0.00;
  double _appendSum = 0.00;

  MockBleService() {
    // 초기값은 전부 0.00으로 유지하므로 별도 루프 없음
  }

  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  @override
  Stream<List<int>> get receivedPacketsStream => _receivedPacketsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isTestMode => _isTestMode;

  bool _bypassTimeoutHold = false;

  @override
  void setTestMode(bool testMode) {
    _isTestMode = testMode;
  }

  @override
  void setBypassTimeoutHold(bool hold) {
    _bypassTimeoutHold = hold;
  }

  @override
  Future<void> connect(String macAddress, {bool autoConnect = false}) async {
    _isConnected = true;
    _connectionStateController.add(true);
    print("Mock BLE 서비스 연결 가동 (테스트 모드 진입)");

    // 연결 수립 즉시 Handshaking 시작 알림 BT_START_REQ (0x01) 가상 송출
    _fireFakeIncomingPacket(Opcodes.btStartReq, []);
  }

  @override
  Future<bool> scanForDevice(String macAddress) async {
    print("Mock BLE 서비스: 스캔 후 기기 발견 대기 중...");
    await Future.delayed(const Duration(seconds: 3));
    return true;
  }

  @override
  Future<void> disconnect() async {
    _injectionTimer?.cancel();
    _isConnected = false;
    _connectionStateController.add(false);
    print("Mock BLE 서비스 연결 해제");
  }

  @override
  Future<void> manualDisconnect() async {
    await disconnect();
  }

  @override
  Future<void> sendPacket(List<int> packet) async {
    if (!_isConnected) {
      print("[DEBUG] MockBleService.sendPacket: ignored because isConnected=false");
      return;
    }

    onPacketSent?.call(packet);

    final int opCode = packet[1];
    final int dataLen = packet[2];
    print("[DEBUG] MockBleService.sendPacket: received Opcode=0x${opCode.toRadixString(16)}, length=$dataLen");

    // 즉시 응답(ACK) 메시지 반환 모의
    if (!_bypassTimeoutHold) {
      _fireFakeIncomingPacket(Opcodes.btMsgRes, [opCode, ResCode.ok.value]);
    } else {
      print("[DEBUG] MockBleService: Timeout Hold 활성화됨. 자동 ACK(0x00) 응답을 생략합니다.");
    }

    switch (opCode) {
      case Opcodes.btConnectableCtrlReq:
        // 통신 개시 수락 -> 장치 상태 IDLE 통보
        if (!_bypassTimeoutHold) {
          _fireFakeIncomingPacket(Opcodes.btStateInd, [PumpState.idle.value]);
        }
        break;

      case Opcodes.btStateReq:
        // 상태 조회에 대한 응답 (테스트를 위해 1초 지연)
        if (_bypassTimeoutHold) {
          print("[DEBUG] MockBleService: Timeout Hold 활성화됨. 자동 상태응답(0x05)을 생략합니다.");
          break;
        }
        Future.delayed(const Duration(seconds: 1), () {
          if (_isConnected) {
            _fireFakeIncomingPacket(Opcodes.btStateInd, [PumpState.idle.value]);
          }
        });
        break;

      case Opcodes.btCurTimeInd:
        // 시간 동기화 수신 -> 펌프에서 앱으로 동일 시간 회신
        if (_bypassTimeoutHold) {
          print("[DEBUG] MockBleService: Timeout Hold 활성화됨. 자동 시간응답(0x44)을 생략합니다.");
          break;
        }
        if (dataLen >= 6) {
          final timeData = packet.sublist(3, 9);
          _fireFakeIncomingPacket(Opcodes.btCurTimeRes, timeData);
        }
        break;

      case Opcodes.btPrsAppPasswdReq:
        // 패스워드 조회 요청 -> 현재 패스워드 ('000000') 회신
        final passwdBytes = _password.codeUnits;
        _fireFakeIncomingPacket(Opcodes.btPrsAppPasswdRes, passwdBytes);
        break;

      case Opcodes.btBattDataReq:
        // 배터리 잔량 요청 -> 현재 50% (0x02) 수준 전달
        _fireFakeIncomingPacket(Opcodes.btBattDataInd, [_batteryLevel]);
        break;

      case Opcodes.btPumpPidReq:
        // 고유 PID 요청 -> 16Byte 문자열 전달
        final pidBytes = 'PUMP1234567890AB'.codeUnits;
        _fireFakeIncomingPacket(Opcodes.btPumpPidRes, pidBytes);
        break;

      case Opcodes.btPumpFwReq:
        // 펌웨어 버전 요청 -> v1.0 (major=0x01, minor=0x00) 전달
        _fireFakeIncomingPacket(Opcodes.btPumpFwRes, [0x01, 0x00]);
        break;

      case Opcodes.btEatValueReq:
        // 식사 설정값 요청 -> 아침, 점심, 저녁 설정량 회신 (각 2B Little-endian, Scale x100)
        final List<int> data = List.filled(6, 0);
        PacketParser.writeUint16(data, 0, (_mealSettings['breakfast']! * 100).round());
        PacketParser.writeUint16(data, 2, (_mealSettings['lunch']! * 100).round());
        PacketParser.writeUint16(data, 4, (_mealSettings['dinner']! * 100).round());
        _fireFakeIncomingPacket(Opcodes.btEatValueRes, data);
        break;

      case Opcodes.btBaseValueReq:
        // 24구간 기초 설정값 요청 -> 3회 분할 전송 모의 (17B씩)
        for (int group = 1; group <= 3; group++) {
          final List<int> data = List.filled(17, 0);
          data[0] = group; // time_param (1, 2, 3)
          final int startHour = (group - 1) * 8;
          for (int hour = 0; hour < 8; hour++) {
            final double rate = _basalRates[startHour + hour];
            PacketParser.writeUint16(data, 1 + (hour * 2), (rate * 100).round());
          }
          _fireFakeIncomingPacket(Opcodes.btBaseValueRes, data);
        }
        break;

      case Opcodes.btTimeBaseSetReq:
        // 기초 설정 저장
        if (dataLen >= 9) {
          final int group = packet[3];
          final int startHour = (group - 1) * 4;
          for (int i = 0; i < 4; i++) {
            final int rawVal = PacketParser.readUint16(packet, 4 + (i * 2));
            _basalRates[startHour + i] = rawVal / 100.0;
          }
          // 저장 결과 BT_SET_RES 반환 (설정일자 6B + 인슐린잔량 2B)
          final List<int> resData = List.filled(8, 0);
          resData.setRange(0, 6, PacketParser.serializeDate(DateTime.now()));
          PacketParser.writeUint16(resData, 6, _insulinRemain);
          _fireFakeIncomingPacket(Opcodes.btSetRes, resData);
        }
        break;

      case Opcodes.btMealSetReq:
        // 식사 설정 저장
        if (dataLen >= 3) {
          final int mealType = packet[3];
          final int rawVal = PacketParser.readUint16(packet, 4);
          final double val = rawVal / 100.0;
          if (mealType == 0) _mealSettings['breakfast'] = val;
          if (mealType == 1) _mealSettings['lunch'] = val;
          if (mealType == 2) _mealSettings['dinner'] = val;

          // 저장 결과 BT_SET_RES 반환
          final List<int> resData = List.filled(8, 0);
          resData.setRange(0, 6, PacketParser.serializeDate(DateTime.now()));
          PacketParser.writeUint16(resData, 6, _insulinRemain);
          _fireFakeIncomingPacket(Opcodes.btSetRes, resData);
        }
        break;

      case Opcodes.btInjInfoReq:
        // 주입 정보 조회 -> BT_INJ_INFO_RES 반환
        final int type = packet[3]; // 0: 식사, 1: 추가
        final List<int> data = List.filled(11, 0);
        data[0] = type == 0 ? 2 : 4; // 식사(점심 2) 또는 추가(4)
        data.setRange(1, 7, PacketParser.serializeDate(DateTime.now()));
        PacketParser.writeUint16(data, 7, (type == 0 ? _mealSettings['lunch']! : 5.0 * 100).round());
        PacketParser.writeUint16(data, 9, _insulinRemain);
        _fireFakeIncomingPacket(Opcodes.btInjInfoRes, data);
        break;

      case Opcodes.btInjReq:
        // 주입 시작 모의 (식사 또는 추가)
        final int type = packet[3];
        final int rawVal = PacketParser.readUint16(packet, 4);
        final double injVal = rawVal / 100.0;

        // 실제 기기처럼 내부 잔량 차감 및 누적량 합산
        _insulinRemain = (_insulinRemain - rawVal).clamp(0, 30000);
        
        if (type == 0) {
          // 식사 주입: 현재 시간 기준으로 아침/점심/저녁 누적에 합산
          final hour = DateTime.now().hour;
          if (hour >= 6 && hour < 11) {
            _morningSum += injVal;
          } else if (hour >= 11 && hour < 17) {
            _lunchSum += injVal;
          } else {
            _eveningSum += injVal;
          }
        } else {
          // 추가 주입
          _appendSum += injVal;
        }

        // 주입 시작 알림
        _fireFakeIncomingPacket(Opcodes.btInjStartInd, []);
        break;

      case Opcodes.btExerciseSetReq:
        // 운동 적용 시작 모의
        final int active = packet[3];
        final int hours = packet[4];
        final int reduction = packet[5];

        if (active == 1) {
          // 8Byte: 시간 + 감량% + 시작 날짜 6B
          final List<int> startData = List.filled(8, 0);
          startData[0] = hours;
          startData[1] = reduction;
          startData.setRange(2, 8, PacketParser.serializeDate(DateTime.now()));
          _fireFakeIncomingPacket(Opcodes.btExerciseInjStartInd, startData);

          // 5초 완료 카운터 기동
          _injectionTimer?.cancel();
          _injectionTimer = Timer(const Duration(seconds: 5), () {
            final List<int> stopData = List.filled(6, 0);
            stopData.setRange(0, 6, PacketParser.serializeDate(DateTime.now()));
            _fireFakeIncomingPacket(Opcodes.btExerciseInjStopInd, stopData);
          });
        }
        break;

      case Opcodes.btReceptionSetReq:
        // 회식 적용 시작 모의
        final int active = packet[3];
        final int hours = packet[4];

        if (active == 1) {
          // 7Byte: 시간 + 시작 날짜 6B
          final List<int> startData = List.filled(7, 0);
          startData[0] = hours;
          startData.setRange(1, 7, PacketParser.serializeDate(DateTime.now()));
          _fireFakeIncomingPacket(Opcodes.btReceptionInjStartInd, startData);

          // 5초 완료 카운터 기동
          _injectionTimer?.cancel();
          _injectionTimer = Timer(const Duration(seconds: 5), () {
            final List<int> stopData = List.filled(6, 0);
            stopData.setRange(0, 6, PacketParser.serializeDate(DateTime.now()));
            _fireFakeIncomingPacket(Opcodes.btReceptionInjStopInd, stopData);
          });
        }
        break;

      case Opcodes.btInjStopReq:
        // 긴급 정지 모의
        _injectionTimer?.cancel();
        // 장치 정지 상태 전이 및 통보
        _fireFakeIncomingPacket(Opcodes.btStateInd, [PumpState.normalStop.value]);
        break;

      case Opcodes.btLogReq:
        // 180일치 가상 데이터 벌크 수집 모의
        // 1. 대량 데이터 전송 개시
        _fireFakeIncomingPacket(Opcodes.btDataStartInd, []);
        
        // 2. 180회 루프 송신 (헤더 없이 20Byte 패킷을 직접 쏨)
        final now = DateTime.now();
        for (int i = 179; i >= 0; i--) {
          final logDate = now.subtract(Duration(days: i));
          final List<int> logBytes = List.filled(20, 0);
          logBytes[0] = logDate.month;
          logBytes[1] = logDate.day;
          
          PacketParser.writeUint16(logBytes, 2, (0.00 * 100).round());  // 0.00U (기초)
          PacketParser.writeUint16(logBytes, 4, (0.00 * 100).round());  // 0.00U (식사)
          PacketParser.writeUint16(logBytes, 6, (0.00 * 100).round());  // 0.00U (아침)
          PacketParser.writeUint16(logBytes, 8, (0.00 * 100).round());  // 0.00U (점심)
          PacketParser.writeUint16(logBytes, 10, (0.00 * 100).round()); // 0.00U (저녁)
          PacketParser.writeUint16(logBytes, 12, (0.00 * 100).round()); // 0.00U (추가)
          
          _receivedPacketsController.add(logBytes);
          CloudSyncService().emitRxPacket(logBytes, deviceMac: "MOCK_DEVICE_MAC");
        }

        // 3. 대량 데이터 전송 종료
        _fireFakeIncomingPacket(Opcodes.btDataEndInd, []);
        break;

      case Opcodes.btLogInjQntReq:
        // 금일 누적 주입량 요청 -> BT_LOG_INJ_QNT_IND 전달
        final List<int> qntData = List.filled(13, 0);
        final dt = DateTime.now();
        qntData[0] = dt.hour;
        qntData[1] = dt.minute;
        qntData[2] = dt.second;
        PacketParser.writeUint16(qntData, 3, (_basalSum * 100).round()); // 기초누적
        PacketParser.writeUint16(qntData, 5, (_morningSum * 100).round()); // 아침누적
        PacketParser.writeUint16(qntData, 7, (_lunchSum * 100).round()); // 점심누적
        PacketParser.writeUint16(qntData, 9, (_eveningSum * 100).round()); // 저녁누적
        PacketParser.writeUint16(qntData, 11, (_appendSum * 100).round());// 추가누적
        _fireFakeIncomingPacket(Opcodes.btLogInjQntInd, qntData);
        break;

      case Opcodes.btStopCtrlReq:
        // 일시정지 제어 요청
        final int pause = packet[3];
        _fireFakeIncomingPacket(Opcodes.btStateInd, [pause == 1 ? PumpState.normalStop.value : PumpState.idle.value]);
        break;
    }
  }

  /// 20Byte 패킷 생성 후 수신 스트림 방출
  void _fireFakeIncomingPacket(int opCode, List<int> data) {
    final packet = List<int>.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = opCode;
    packet[2] = data.length;
    for (int i = 0; i < data.length; i++) {
      packet[3 + i] = data[i];
    }
    _receivedPacketsController.add(packet);
    // [Cloud Integration] RX 방송
    CloudSyncService().emitRxPacket(packet, deviceMac: "MOCK_DEVICE_MAC");
  }

  // === [TEST MODE ONLY] ===
  /// 가상의 BT_INJ_STOP_IND (0x3B) 주입 완료 패킷을 생성하여 외부 스트림으로 강제 송출합니다.
  void fireFakeStopPacket() {
    print("Mock BLE 서비스: 가상의 주입 완료 패킷(0x3B)을 강제 트리거합니다.");
    final List<int> stopData = List.filled(11, 0);
    stopData[0] = 2; // 식사 주입(2) 완료 모의
    stopData.setRange(1, 7, PacketParser.serializeDate(DateTime.now()));
    PacketParser.writeUint16(stopData, 7, 100); // 인슐린 설정값 (1.00 U = 100)
    PacketParser.writeUint16(stopData, 9, _insulinRemain); // 잔량 2B
    _fireFakeIncomingPacket(Opcodes.btInjStopInd, stopData);
  }
  // ========================

  @override
  Future<void> setPauseState(bool pause) async {
    _isPaused = pause;
    print("Mock BLE 서비스: 일시정지 상태 변경 -> $_isPaused");

    // 가상으로 앱 -> 기기 패킷 송출 모사
    final List<int> packet = List.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btStopCtrlReq;
    packet[2] = 1;
    packet[3] = pause ? 1 : 0;
    onPacketSent?.call(packet);

    // 기기 상태 인디케이션 모의 전송
    _fireFakeIncomingPacket(
      Opcodes.btStateInd,
      [pause ? PumpState.normalStop.value : PumpState.idle.value],
    );
  }

  @override
  Future<void> resetDevice() async {
    print("Mock BLE 서비스: 장치 초기화 실행 (BT_SYSEM_RESET 전송, 연결 유지)");

    // 가상으로 앱 -> 기기 패킷 송출 모사
    final List<int> packet = List.filled(20, 0);
    packet[0] = kStartCode;
    packet[1] = Opcodes.btSystemReset;
    packet[2] = 0;
    onPacketSent?.call(packet);

    // 초기화 메시지 전송 모의
    _fireFakeIncomingPacket(Opcodes.btSystemReset, []);
  }
}
