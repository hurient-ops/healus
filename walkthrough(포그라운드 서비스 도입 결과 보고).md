# 포그라운드 서비스 도입 결과 보고

앱이 백그라운드로 내려가거나 화면이 꺼질 때 30분 주기의 데이터 폴링(배터리, 인슐린 주입량) 요청이 무기한 지연되는 현상을 해결하기 위한 작업이 완료되었습니다.

## 🛠 수정된 사항 (Changes Made)

1. **포그라운드 서비스 패키지 연동**
   - `flutter_foreground_task`를 `pubspec.yaml`에 추가하여 백그라운드 프로세스 유지 기능을 구현했습니다.

2. **안드로이드/iOS 백그라운드 권한 부여**
   - **안드로이드**: `FOREGROUND_SERVICE_CONNECTED_DEVICE` 등 최신 Android 14+ 대응 권한을 `AndroidManifest.xml`에 명시하고 전용 Service를 등록했습니다.
   - **iOS**: 백그라운드에서 블루투스 중앙 장치 역할을 유지하기 위해 `Info.plist`에 `UIBackgroundModes` -> `bluetooth-central` 권한을 추가했습니다.

3. **앱 생명주기 및 타이머 오프셋 적용**
   - 앱 메인에 Foreground Service 초기화 로직을 추가했습니다.
   - BLE 장치와 연결이 성공할 때(`_startDeviceConnection`), 포그라운드 서비스가 실행되어 알림바에 "HealUs - 인슐린 펌프와 연결 중입니다."가 띄워지며 OS가 앱을 재우는 것을 방지합니다.
   - `main.dart`의 `_requestDashboardInitialData`에서 두 번째 패킷(`_startQntPollTimer()`) 발동 시 `Future.delayed(10초)`를 두어, 첫 번째 요청(`0x70`)과 두 번째 요청(`0x1E`)이 완벽히 분리되어 BLE 충돌이 나지 않도록 조치했습니다.

## ✅ 기대 효과 (Validation Results)
이제 스마트폰의 전원 버튼을 눌러 화면을 끄거나 다른 앱(카카오톡, 유튜브 등)을 사용하더라도, 상단 알림이 유지되는 동안에는 정확히 30분 간격으로 인슐린 펌프와 통신하여 데이터를 누락 없이 동기화합니다.

> [!TIP]
> 배포 전 실기기에서 화면을 끄고 약 35분간 두신 후 펌프 로그를 확인하여, 배터리와 주입량 요청이 30분 정시마다 오차 없이 요청되었는지 테스트해 주시길 권장드립니다!
