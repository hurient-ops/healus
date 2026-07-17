# Bluetooth 기기 검색 및 선택 UI 연동 계획

현재 하드코딩된 MAC 주소로 무조건 연결하는 방식에서 벗어나, 주변 블루투스 장치(인슐린 펌프)를 검색하여 화면에 표시하고 사용자가 직접 선택하여 연결할 수 있도록 기능 고도화를 진행합니다.

## User Review Required
> [!IMPORTANT]
> - Android 12 이상에서 요구하는 엄격한 런타임 권한(BLUETOOTH_SCAN, BLUETOOTH_CONNECT)을 획득하기 위해 `permission_handler` 플러그인을 추가로 사용합니다.
> - **[iOS MAC 주소 은닉 대응]** 애플(Apple)의 개인정보 보호 정책으로 인해 iOS 기기에서는 진짜 하드웨어 MAC 주소가 아닌 무작위 생성된 **UUID**를 반환합니다. 이를 대응하기 위해, Flutter 내부 및 웹뷰 통신 시 식별자 변수명은 통일하되, **안드로이드에서는 '실제 12자리 MAC 주소'**를 표출하고, **iOS에서는 '애플 고유 UUID'를 그대로 사용하여 연결 식별자로 활용**하도록 완벽 호환 설계합니다. UI 상에서 긴 UUID가 화면을 망치지 않도록 iOS 식별자는 적절히 가공(예: 뒷자리 일부만 표시)하여 보여줄 수 있습니다. 
>   - *참고: 만약 펌프가 Advertising 패킷(Manufacturer Data) 내부에 자신의 MAC 주소를 담아서 쏘고 있다면, iOS에서도 해당 패킷을 파싱해 진짜 MAC을 표시할 수 있습니다.*

## Proposed Changes

### 1. 설정 및 권한 부여
#### [MODIFY] [pubspec.yaml](file:///e:/projects/healus/pubspec.yaml)
- 런타임 권한 요청을 위해 `permission_handler: ^11.3.1` 패키지 추가

#### [MODIFY] [AndroidManifest.xml](file:///e:/projects/healus/android/app/src/main/AndroidManifest.xml)
- `BLUETOOTH`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION` 권한 선언 추가 (Android 하위 호환성 및 12 이상 지원)

#### [MODIFY] [Info.plist](file:///e:/projects/healus/ios/Runner/Info.plist)
- iOS 환경에서의 블루투스 사용 권한(`NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`) 안내 문구 추가

---

### 2. UI 및 로직 연동 (WebView)
#### [MODIFY] [code.html (ble_connect)](file:///e:/projects/healus/ui_design/ble_connect/code.html)
- `setTimeout`으로 프론트엔드에 하드코딩되어 있던 가짜 장치 Mock 로직을 제거합니다.
- 권한 수락 시 `console.log("BLE Command Sent: [START_SCAN]")`을 발생시켜 Flutter 쪽에 검색 시작을 명령합니다.
- `window.updateFoundDevices(json)` 함수를 노출하여 Flutter가 보내주는 기기 목록을 화면(React 상태)에 렌더링하도록 변경합니다.
- 기기 선택 시 `../password/code.html?mac=[선택된 MAC]` 형태로 라우팅하여 Flutter가 사용자가 고른 기기의 주소를 낚아챌 수 있게 만듭니다.

---

### 3. 통신 브릿지 및 디바이스 연결 제어 (Flutter)
#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- `_handleConsoleMessage` 내에 `[START_SCAN]` 명령 핸들러를 추가합니다.
- **[테스트(디버그) 모드 분기]** `kReleaseMode` 플래그를 활용하여 두 가지 방식으로 스캔을 처리합니다:
  - **`!kReleaseMode` (에뮬레이터/디버그):** 실제 스캔을 돌리지 않고, 1.2초 대기 후 기존 테스트용 기기 정보(`20:73:6A:19:3E:41`)를 담은 가상 JSON을 웹뷰로 전달합니다. (에뮬레이터에서도 정상적으로 UI 플로우 테스트 가능)
  - **`kReleaseMode` (상용 릴리즈):** `permission_handler`를 통해 진짜 권한을 획득하고, `FlutterBluePlus.startScan()`을 호출하여 실제 주변 블루투스 펌프를 스캔합니다.
- `FlutterBluePlus.scanResults` 스트림을 수신하여 장치들을 파싱합니다.
  - **Android**: `device.remoteId.str`가 12자리 MAC 주소이므로 이를 그대로 전달합니다.
  - **iOS**: `device.remoteId.str`가 애플의 무작위 UUID이므로, 이를 연결 키(`deviceId`)로 사용하도록 전달합니다.
- 추출한 데이터를 `_controller.runJavaScript("window.updateFoundDevices(...)")`로 웹뷰에 전송합니다.
- `password/code.html` 화면 이동(Navigation)을 감지할 때, 쿼리 파라미터(`?mac=...`)에 담긴 식별자(MAC 또는 UUID)를 추출하여 `_startDeviceConnection(mac)`을 동적으로 호출하도록 수정합니다.

## Verification Plan

### Manual Verification
- 앱 빌드 및 설치 후 구동 시 블루투스/위치 권한 요청 팝업이 정상적으로 표출되는지 확인.
- 권한 허용 시 블루투스 스캔이 진행되고 주변의 BLE 기기들(또는 펌프) 목록이 UI에 출력되는지 확인.
- 표시된 리스트 중 특정 기기를 터치했을 때 해당 MAC 주소를 기반으로 연결 시도 화면(로딩)으로 정상 진입하는지 확인.
