# 가상 BLE 패킷 제어 고도화 및 연동 구현 결과 (Walkthrough)

이 문서는 HealUs 앱의 BLE 통신 메시지 구조 보완, 비밀번호 파싱 개정, 기초 설정의 전역 보존, 수동 제어(타임아웃 홀드) 및 송신 로그 구현 결과를 요약합니다.

---

## 1. 주요 구현 변경점

### A. 비밀번호 디코딩 방식 개정 (ASCII -> 원시 숫자 병합)
- **대상**: [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart#L262-L272)
- **내용**: 기존의 아스키 문자 변환(`String.fromCharCodes`)을 제거하고, 기획서 ver 260608 예시와 수동 디버깅 주입 흐름에 부합하도록 패킷 내 6바이트 바이트 원시 숫자 값을 문자열로 직접 변환 및 결합하도록 수정하였습니다.
  - 예: `0x01 0x02 0x03 0x04 0x05 0x06` -> `"123456"`으로 동기화됩니다.

### B. 인슐린 잔량(0x12, 0x16, 0x3B) 대시보드 실시간 연동
- **대상**: [main.dart](file:///e:/projects/healus/lib/main.dart#L865-L879)
- **내용**: 네이티브의 `pumpStateProvider` 가 수신한 패킷에 의해 인슐린 잔량, 배터리 레벨, 주입 중 상태 등이 갱신될 때마다 `ref.listen`이 이를 실시간 감지하여 `_syncStateToWebview()`를 강제 수행하도록 구현하였습니다. 이에 따라 수동 패킷 주입을 통해 데이터가 업데이트되면 대시보드의 잔량 텍스트와 프로그레시브 바의 width가 실시간으로 자동 렌더링 및 연동됩니다.

### C. 기초 설정 화면(`basal_setting/code.html`) 양방향 실시간 동기화
- **대상**: [main.dart](file:///e:/projects/healus/lib/main.dart#L343-L368) & [basal_setting/code.html](file:///e:/projects/healus/ui_design/basal_setting/code.html#L370-L400)
- **내용**:
  - **진입 시**: 웹뷰 로드 시 콘솔에 `"REQUEST_BASAL_RATES"` 메시지를 출력하며, 네이티브는 이를 포착해 현재 공통 장소의 `basalRates` 값을 웹뷰의 `window.receiveBleBasalData`로 주입해 복구합니다.
  - **설정 및 저장 시**: 값이 수정될 때마다 `"UPDATE_BASAL_RATES: [...]"` 콘솔을 내보내 네이티브 공통 `basalRates` 상태를 실시간 업데이트합니다. 다른 화면으로 이동했다가 다시 진입해도 상태가 완벽히 보존됩니다.

### D. BLE 디버그 패널 고도화 (타임아웃 홀드 및 송신 로그)
- **대상**: [ble_service_provider.dart](file:///e:/projects/healus/lib/services/ble/ble_service_provider.dart), [ble_packet_assembler.dart](file:///e:/projects/healus/lib/services/ble/ble_packet_assembler.dart), [ble_handshake_controller.dart](file:///e:/projects/healus/lib/services/ble/ble_handshake_controller.dart)
- **내용**:
  - **타임아웃 일시정지 (Hold)**: `timeoutHoldProvider`와 `setBypassTimeoutHold` API를 구축해, 이 값이 `true`일 때는 500ms 패킷 재조립 타이머 기동을 전면 억제하고 핸드셰이크 커넥션 대기를 365일로 설정하여 수동 디버깅 도중 타임아웃으로 인한 세션 끊김을 철저히 차단합니다.
  - **송신 패킷 기록**: `sentPacketsLogProvider`를 통해 앱이 펌프로 송신한 패킷들을 타임스탬프와 함께 보관합니다.
  - **UI 개편**: `main.dart`의 `_showDebugPacketDialog` UI에 **타임아웃 홀드 토글 스위치**와 스크롤 가능한 **송신 패킷 로그 패널**을 추가하였습니다.

---

## 2. 검증 결과

- **단위 테스트**: `test/pump_state_provider_test.dart` 내의 신규 패스워드 원시 바이트 패킷 수신 테스트 케이스를 수정 및 보완하여 실행한 결과, 전체 테스트가 정상 통과하였습니다.
  - 실행 명령: `flutter test test/pump_state_provider_test.dart` -> **Success (All tests passed)**

---

## 3. 타임아웃 홀드 원복(롤백) 가이드 프롬프트

수동 디버깅이 끝난 후 다시 원래의 실제 디바이스 통신 타임아웃(재조립 500ms, 연결 3초) 방어 로직으로 **원복**하고 싶을 때는 아래의 두 가지 방법 중 하나를 선택해 진행하실 수 있습니다.

### 방법 A: 디버그 UI 상에서 복구 (가장 간편한 방법)
- 앱에서 **[가상 BLE 패킷 수동 제어 패널]** 다이얼로그를 켭니다.
- **"타임아웃 일시정지 (Hold)"** 토글 스위치를 `비활성화(off)`로 전환합니다.
- 즉시 네이티브 타임아웃 설정이 디바이스 기본값(3초 및 500ms)으로 실시간 원원 복구됩니다.

### 방법 B: 소스 코드를 이전 실제 통신 상태로 원복하고 싶을 때의 롤백 프롬프트
만약 디버깅 기능 자체를 완전히 이전의 실제 하드웨어 통신 방어 사양으로 롤백하여 프로덕션 배포 상태로 만들고 싶다면, Antigravity 에이전트에게 아래 프롬프트를 발송하시면 됩니다:

> **[원복 요청 프롬프트 예시]**
> ```text
> 수동 디버깅을 위해 추가했던 타임아웃 홀드(Hold) 로직과 수동 송신 로그 이력 UI를 완전히 원래 상태로 롤백해줘. 
> 1. ble_packet_assembler.dart의 bypassTimeoutHold 조건문을 제거해줘.
> 2. ble_handshake_controller.dart와 hardware_ble_service.dart의 connect/waitForPacket 타임아웃을 원래의 3초 및 패킷 대기 시간으로 되돌려줘.
> 3. main.dart의 _showDebugPacketDialog() 다이얼로그 UI를 이전의 단순 Hex 패킷 수집 주입 다이얼로그로 복원해줘.
> ```
