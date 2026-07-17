# 메인 설정 및 디바이스 제어 (PAUSE, RESUME, DISCONNECT, RESET) 구현 결과 보고서

이 문서에는 `./ui_design/main_setting` 화면 내 네 가지 디바이스 제어 버튼(일시 정지, 장치 재개, 장치 연결 해제, 장치 초기화)의 네이티브 연동 및 BLE 통신 구현 결과가 요약되어 있습니다.

## 1. 구현된 변경 사항

### A. BLE 서비스 레이어 다형성 구현
- [ble_service_interface.dart](file:///e:/projects/healus/lib/services/ble/ble_service_interface.dart): `setPauseState`, `resetDevice` 추상 메서드를 정의하여 실 기기 및 모의(Mock) 기기에 대한 다형적 제어 구조를 마련했습니다.
- [mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart): 
  - `setPauseState` 호출 시 가상 일시정지 상태(`_isPaused`)를 저장하고, `BT_STATE_IND` 패킷을 가상 송출하여 웹뷰 화면의 상태 전이를 유도합니다.
  - `resetDevice` 호출 시 가상 배터리(100%), 인슐린 잔량(300U), 24시간 기초주입량 및 식사주입량 등의 모의 데이터를 공장 초기화하고 `disconnect`를 호출합니다.
- [hardware_ble_service.dart](file:///e:/projects/healus/lib/services/ble/hardware_ble_service.dart):
  - `setPauseState` 호출 시 `BT_STOP_CTRL_REQ` (0x0D) 패킷(1Byte 페이로드: pause=1, resume=0)을 작성하여 10Byte 분할 송출합니다.
  - `resetDevice` 호출 시 `BT_SYSEM_RESET` (0x43) 패킷(데이터 0)을 기기로 송신하고 물리 연결을 해제합니다.

### B. 웹뷰-네이티브 하이브리드 연동 (브릿지)
- [main.dart](file:///e:/projects/healus/lib/main.dart):
  - **콘솔 인터셉터 추가**: 웹뷰 버튼 클릭 시 발생하는 `BLE Command Sent: [PAUSE/RESUME/DISCONNECT/RESET]` 로그를 감지하여 적절한 `bleService` 제어 함수로 바인딩했습니다.
  - **초기 상태 주입**: 메인 설정 화면(`main_setting/code.html`) 로드 완료 시 펌프의 전역 일시정지 여부(`isPaused`) 상태를 파악해 `localStorage.setItem('isPaused', 'true/false')`로 주입합니다.
- [code.html (main_setting)](file:///e:/projects/healus/ui_design/main_setting/code.html):
  - `SettingsScreen` React 컴포넌트 마운트 시 `isPaused` 상태를 하드코딩된 `false`가 아닌, 네이티브가 로드 시점에 주입해 준 `localStorage.getItem('isPaused')` 값을 기준으로 초기화하도록 패치했습니다.

---

## 2. 검증 계획 및 수동 테스트 가이드

### A. 자동 빌드 및 단위 테스트 검증
- `flutter test` 명령어를 실행하여 새로 추가된 인터페이스와 구현체가 기존 BLE 패킷 결합 및 주입기 컴포넌트와 충돌 없이 올바르게 빌드 및 작동하는지 검증합니다.

### B. 시뮬레이션 및 수동 테스트 시나리오
테스트 모드(Mock Mode)에서 아래 단계에 따라 검증을 수행할 수 있습니다.

1. **장치 연결 및 설정 진입**:
   - 앱 구동 후, 검색된 `HealUS` 장치를 클릭하여 연결을 시작합니다.
   - 비밀번호 입력 창에 `'000000'`을 입력하여 인증을 마치고 대시보드로 이동합니다.
   - 하단 탭 바에서 **설정** 버튼을 눌러 메인 설정(`main_setting/code.html`) 화면에 진입합니다.

2. **일시 정지 & 장치 재개 테스트**:
   - **일시 정지** 버튼을 클릭하고 팝업에서 **예**를 선택합니다.
   - 네이티브에서 `isPaused = true`가 적용되고 버튼 이름이 **장치 재개**로 정상 변경되는지 확인합니다.
   - 홈 탭으로 돌아갔다가 다시 설정 탭에 진입해도 상태가 유지되어 **장치 재개** 버튼이 유지되어 렌더링되는지 검증합니다.
   - **장치 재개** 버튼을 클릭하고 팝업에서 **예**를 선택하여 다시 **일시 정지**로 복원되는지 확인합니다.

3. **장치 연결 해제 테스트**:
   - **장치 연결 해제** 버튼을 클릭하고 팝업에서 **예**를 선택합니다.
   - 물리/가상 연결이 즉각 종료되며 앱이 기기 검색 및 허용 화면(`ble_connect/code.html`)으로 강제 전이되는지 검증합니다.

4. **장치 초기화 테스트**:
   - **장치 초기화** 버튼을 클릭하고 팝업에서 **예**를 선택합니다.
   - "초기화가 완료되었습니다." 팝업이 뜨고 **OK**를 누르면 연결이 해제되어 연결 화면으로 이동하는지 확인합니다.
   - 다시 기기에 연결해 대시보드에 들어갔을 때, 배터리(100%), 인슐린 잔량(300U), 당일 누적 주입량(0U) 등으로 모든 데이터가 포맷되었는지 확인합니다.
