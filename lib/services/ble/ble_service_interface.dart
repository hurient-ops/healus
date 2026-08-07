import 'dart:async';

/// HealUs 인슐린 펌프와의 BLE 연결 및 패킷 송수신을 추상화한 인터페이스
abstract class BleService {
  /// BLE 연결 상태 스트림 (true: 연결됨, false: 연결 해제됨)
  Stream<bool> get connectionStateStream;

  /// 조립 완료된 20Byte 패킷의 수신 스트림
  Stream<List<int>> get receivedPacketsStream;

  /// 현재 연결되어 있는지 여부
  bool get isConnected;

  /// 테스트 모드(Mock Mode) 활성화 여부
  bool get isTestMode;

  /// [macAddress] 안드로이드는 MAC (XX:XX:XX:XX:XX:XX), iOS는 UUID
  /// [autoConnect] true인 경우 안드로이드 시스템 백그라운드 무한 대기 자동 재연결 사용 (타임아웃 없음)
  Future<void> connect(String macAddress, {bool autoConnect = false});

  /// 기기가 스캔될 때까지 대기하며, 발견되면 true 반환 (타임아웃 시 false)
  Future<bool> scanForDevice(String macAddress);

  /// BLE 연결 해제
  Future<void> disconnect();

  /// 사용자의 명시적 조작에 의한 완전 연결 해제 (자동 재연결 방지용)
  Future<void> manualDisconnect();

  /// 20Byte 논리 패킷을 10Byte씩 분할 송신
  Future<void> sendPacket(List<int> packet);

  /// 테스트 모드 강제 설정
  void setTestMode(bool testMode);

  /// 타임아웃 홀드 플래그 설정 (수동 디버깅 용)
  void setBypassTimeoutHold(bool hold);

  /// 장치 일시 정지 설정/해제 제어 (BT_STOP_CTRL_REQ)
  Future<void> setPauseState(bool pause);

  /// 장치 초기화 (시스템 리셋 BT_SYSEM_RESET)
  Future<void> resetDevice();

  /// 패킷 송신 완료 시 호출될 콜백 등록
  void Function(List<int>)? onPacketSent;
}
