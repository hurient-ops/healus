# 인슐린 펌프 모바일 앱 개발 계획서 및 BLE 메시지 규격 100% 반영 설계

이 계획서는 `./plan/인슐린펌프_모바일앱_개발계획서.md` 및 `./plan/In_pump_msg_set_260606.md` 규격을 100% 적용하여 하이브리드(웹뷰) 앱과 플러터 백그라운드 BLE 통신 레이어 간의 동기화 및 데이터 매핑을 구현하기 위한 설계서입니다.

## User Review Required

> [!IMPORTANT]
> - **UI 및 화면 기능 100% 유지**: `./ui_design` 폴더 하위의 HTML/CSS/JS 코드는 그대로 두고, 플러터 네이티브 웹뷰에서 자바스크립트 채널(`setOnConsoleMessage`) 및 데이터 주입(`runJavaScript`)을 통해 연동합니다.
> - **비밀번호 인증 연동**: `password/code.html` 화면에 하드코딩된 `'000000'` 비밀번호 인증을 실제 펌프 디바이스와 통신하여 획득한 암호(`BT_PRS_APP_PASSWD_RES`)와 동적으로 일치하도록 가로채기(웹뷰 주입) 기법을 사용하여 동기화합니다.
> - **BLE 수신 시뮬레이터 타이머 비활성화**: 웹뷰 내부의 5초 완료 시뮬레이션 타이머를 끄기 위해, 웹뷰 로딩 시 `localStorage.setItem('CONFIG_USE_TIMER', 'false')`를 주입하고 실제 BLE 완료 알림(`BT_INJ_STOP_IND`)이 오면 `isInjecting` 상태를 종료하도록 연결합니다.

## Proposed Changes

### [BLE 통신 레이어]

#### [MODIFY] [ble_packet_assembler.dart](file:///e:/projects/healus/lib/services/ble/ble_packet_assembler.dart)
- 첫 번째 10Byte 청크 수신 후 두 번째 청크가 수신되지 않는 경우에 대한 **500ms 패킷 재조립 타임아웃**을 구현합니다.
- 타임아웃 발생 시, 수신 버퍼를 초기화하고 외부 콜백을 통해 재연결을 시도하도록 구조를 변경합니다.

#### [MODIFY] [ble_packet_transmitter.dart](file:///e:/projects/healus/lib/services/ble/ble_packet_transmitter.dart)
- 10Byte 분할 전송 마진 시간을 기존 30ms에서 **50ms ~ 100ms** (설계 표준 75ms 적용)로 상향 조정합니다.

### [상태 및 제어 레이어]

#### [MODIFY] [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
- 펌프 고유 PID, 펌웨어 버전, 아침/점심/저녁 설정값, 24시간 기초 설정 데이터, 오늘 주입량 요약 정보(기초, 식사, 추가 누적량), 디바이스 인증용 비밀번호 상태 데이터를 보유하도록 `PumpStateData` 모델을 확장합니다.
- `BT_EAT_VALUE_RES`, `BT_BASE_VALUE_RES`, `BT_LOG_INJ_QNT_IND`, `BT_PUMP_PID_RES`, `BT_PUMP_FW_RES`, `BT_PRS_APP_PASSWD_RES` 등 ver 260606 규격에 명시된 신규/변경 패킷들의 파싱 및 상태 매핑 핸들러를 완비합니다.

#### [MODIFY] [basal_sync_controller.dart](file:///e:/projects/healus/lib/services/sync/basal_sync_controller.dart)
- 24시간 기초 설정값 저장 완료(`BT_SET_RES`) 수신 시 인슐린 잔량 정보를 업데이트하고 로컬 DB에 주입 날짜를 기록합니다.
- 15일치 대량 이력 로그(`BT_DATA_START_IND` ~ `BT_DATA_END_IND`)를 헤더 없이 수신하여 local DB에 Bulk Insert하는 파이프라인의 안전성을 보강합니다.

### [웹뷰 연동 레이어]

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- `WebViewHomeScreen`에 `setOnConsoleMessage` 채널을 설정하여 웹뷰 내에서 출력되는 BLE 명령 전송 로그를 감지하고, 네이티브 BLE 컨트롤러(`InjectController`, `BasalSyncController`)의 메서드와 실시간 바인딩합니다.
- `onPageFinished` 딜리게이트를 통해 각 화면에 진입할 때마다:
  - **대시보드**: `pumpStateProvider` 및 local DB에서 읽어온 상태 데이터를 웹뷰의 DOM 요소(`val-basal`, `val-meal`, `val-add`, `val-battery-pct`, `val-insulin` 등)에 강제 주입하여 화면을 갱신합니다.
  - **비밀번호**: 디바이스 비밀번호 혹은 공통 저장소 비밀번호를 웹뷰 전역 변수나 DOM 영역에 강제 세팅하여 입력 PIN과 맞물리게 처리합니다.
  - **기초/식사 설정**: BLE로 수신해둔 설정값을 웹뷰의 `localStorage` 및 `receiveBleMealData` / `receiveBleBasalData` 함수 호출을 통해 화면 컨트롤러에 동기화합니다.
  - **주입 중 강제 제어**: `isInjecting` 상태일 때 운동/식사/추가/회식 화면 진입 시 대시보드로 자동 튕겨나가게 하고 토스트를 띄우는 브릿지 상태를 실시간 연동합니다.

## Verification Plan

### Automated Tests
- `flutter test`를 구동하여 패킷 조립기(500ms 타임아웃), 패킷 송신 마진(75ms), 24시간 기초 설정 분할 송신 체인의 단위 테스트가 오차 없이 통과하는지 검증합니다.

### Manual Verification
- 웹뷰 앱을 에뮬레이터에서 구동하여:
  1. BLE 연결 및 세션 수립 단계에서 Handshaking 패킷 송수신 흐름 검증
  2. 비밀번호 불일치 시 셰이크 애니메이션 작동 및 일치 시 대시보드 진입 확인
  3. 대시보드에서 각 주입 요청 시 "주입 요청 모달" -> "주입 중 배지" 활성화 -> BLE 완료 메시지 수신 시 "완료 모달" 순차 트리거 검증
  4. 24시간 기초 설정 및 식사 설정 저장 시 네이티브 BLE 패킷이 실제 6회 및 3회로 쪼개져 75ms 마진으로 올바르게 송신되는지 로그 확인
