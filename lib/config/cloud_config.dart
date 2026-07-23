class CloudConfig {
  /// 클라우드 통신 스위치: true이면 백엔드 서버와 통신, false이면 완전 오프라인 모드
  static const bool enableCloudSync = true;

  /// 백엔드 서버 베이스 주소
  /// 로컬 에뮬레이터 테스트용: http://10.0.2.2:8000
  /// 로컬 네트워크 실기기 테스트용: http://[PC_IP]:8000
  /// 실제 클라우드 서버 배포 시: https://api.healus.io
  static const String serverBaseUrl = "http://10.0.2.2:8000";
}
