# 블루투스 기기 스캔 및 에뮬레이터 Mock 지원 구현 완료

기존 하드코딩된 단일 MAC 주소 연결 방식을 걷어내고, 실제 주변 블루투스 기기를 스캔하여 화면에 표시하는 기능을 구현 완료했습니다. 또한 에뮬레이터 구동 시(`!kReleaseMode`)에는 블루투스 없이도 기존처럼 가짜 기기(Mock Device)가 뜨도록 완벽하게 처리했습니다.

## 주요 변경 사항

### 1. 설정 및 권한 연동
- `permission_handler` 플러그인을 도입하여 Android 12+ 의 `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` 등 까다로운 권한과 iOS 위치/블루투스 권한을 손쉽게 획득할 수 있도록 권한 정책을 추가했습니다.
- [AndroidManifest.xml](file:///e:/projects/healus/android/app/src/main/AndroidManifest.xml) 및 [Info.plist](file:///e:/projects/healus/ios/Runner/Info.plist) 에 필수 블루투스 권한 스펙 정의 완료.

### 2. 웹뷰 UI 브릿지 고도화
- [ui_design/ble_connect/code.html](file:///e:/projects/healus/ui_design/ble_connect/code.html) 내부의 프론트엔드 단 하드코딩 대기(setTimeout)를 과감하게 삭제했습니다.
- 사용자가 권한을 허용하면 `console.log("BLE Command Sent: [START_SCAN]")` 신호를 쏘고, Flutter가 `window.updateFoundDevices(...)` 함수를 직접 호출해 기기를 꽂아주도록 반응형 구조로 탈바꿈했습니다.
- 기기 클릭 시 해당 기기의 고유 식별자(`mac`)를 URL 쿼리로 실어보내(`../password/code.html?mac=...`) Flutter가 낚아챌 수 있도록 동적 라우팅을 적용했습니다.

### 3. 디버그/릴리즈 환경 완벽 분리
- [main.dart](file:///e:/projects/healus/lib/main.dart) 에 새롭게 추가된 `_startBleScan()` 함수가 핵심입니다.
- **개발 환경 (`!kReleaseMode`)**: 에뮬레이터에서 스캔을 시도하면 가짜 장치 `[HealUS (Mock), 20:73:6A:19:3E:41]`를 즉시 응답하여 개발 편의성을 그대로 유지합니다.
- **운영 환경 (`kReleaseMode`)**: 권한 승인 후 `FlutterBluePlus.startScan()`을 통해 진짜 주변 BLE 펌프들을 탐색하고 화면에 띄웁니다.

## 테스트 및 확인 방법
1. **에뮬레이터 구동**: `flutter run`으로 실행 후 스캔 버튼을 누르면 1.2초 후 기존처럼 테스트 기기(Mock)가 나타납니다.
2. **실기기 구동 (릴리즈 빌드)**: `flutter run --release`로 안드로이드 스마트폰에서 실행 시, 진짜 블루투스 권한 팝업이 뜨고 허용 시 내 주변의 블루투스 장비들이 화면에 출력됩니다. 해당 장치를 터치하면 기존처럼 패스워드 화면으로 넘어가면서 정상 연결 절차를 밟게 됩니다.
