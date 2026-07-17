# 시간 동기화(Time Synchronization) 로직 개편

기존 장치 연결 시 수행하던 시간 동기화 과정을 앱의 첫 진입점(대시보드)으로 이관하고, 실패 시의 재시도 루프 및 UI 피드백을 강화합니다.

## User Review Required

> [!IMPORTANT]  
> 가상 BLE 테스트 시 '타임아웃 일시정지(Hold)'를 켜두시면 3초 타임아웃 없이 무한 대기 상태가 됩니다. 이때 수동 제어 패널에서 `0x44`(BT_CUR_TIME_RES) 패킷을 주입하셔야 동기화 성공 여부를 테스트할 수 있습니다.

## Proposed Changes

---

### Handshake 로직 변경
#### [MODIFY] [ble_handshake_controller.dart](file:///e:/projects/healus/lib/services/ble/ble_handshake_controller.dart)
- `BT_CUR_TIME_IND (0x06)` 송출 및 `BT_CUR_TIME_RES (0x44)` 수신 대기를 통한 시간 검증 로직 제거.
- 시간 불일치로 인한 `BT_SYSEM_RESET (0x43)` 송출 및 예외(Exception) 발생 구문 삭제.

---

### 시간 동기화 컨트롤러 신규 생성
#### [NEW] [time_sync_controller.dart](file:///e:/projects/healus/lib/services/ble/time_sync_controller.dart)
- 대시보드 진입 시 호출될 `TimeSyncController` 구현.
- `BT_CUR_TIME_IND (0x06)` 패킷 송신 후 `BT_CUR_TIME_RES (0x44)` 수신 대기 (패킷 재조립 타임아웃 규칙 적용하여 **500ms** 대기).
- 수신된 시간 배열(년,월,일,시,분,초)이 보낸 시간과 일치하면 동기화 완료(`isSynced = true`)로 판단.
- **예외 처리:** 500ms 타임아웃 발생이거나 시간 정보가 불일치할 경우 실패로 간주.
- **UI 피드백:** 실패 시 `WebViewController`를 이용해 웹뷰 측에 `"시간 동기화에 실패했습니다"` 토스트 표시. (대시보드에서 사용하는 동일한 커스텀 UI: 검은 바탕에 흰 글씨, 둥근 형태)
- **재시도 루프:** 실패 시 30분 타이머(`Timer.periodic`)를 가동하여 30분 주기로 재요청. 한 번이라도 동기화에 성공하면 해당 루프는 영구 종료.
- **타임아웃 홀드 연동:** `timeoutHoldProvider`가 활성화되어 있으면 500ms 타임아웃을 365일로 우회(Bypass)하여 수동 패킷 주입 무한 대기.

---

### 메인 앱 브릿지 연동
#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- 대시보드(`dashboard/code.html`) 화면이 로딩 완료되는 시점(`onPageFinished` 또는 히스토리 변경 시점)을 감지.
- 상태 확인 후 최초 1회에 한해 `timeSyncControllerProvider`를 통해 동기화 검증 시작(`startTimeSync()`).

---

### 대시보드 UI 연동
#### [MODIFY] [code.html](file:///e:/projects/healus/ui_design/dashboard/code.html)
- 내부 IIFE 스코프에 갇혀있는 `showToast` 함수를 Flutter 측에서 실행할 수 있도록 `window.showToast` 로 전역 개방.
- 전역 개방 시 기존 검은 바탕에 흰 글씨(둥근 형태)의 커스텀 UI가 그대로 유지됨.

## Verification Plan

### Manual Verification
1. **정상 흐름 테스트:** 가상 펌프에서 자동으로 응답하는 `0x44` 패킷을 받아 시간 동기화가 무사히 완료되는지 확인.
2. **실패 흐름 테스트:** 타임아웃을 강제로 발생시키거나 잘못된 시간의 `0x44`를 수동으로 주입하여, 즉시 대시보드 화면 하단에 `"시간 동기화에 실패했습니다"` 토스트가 뜨는지 확인.
3. **홀드 기능 테스트:** 홀드를 켠 상태에서 대시보드 진입 후 무한 대기되는지 확인하고, 수동으로 정답 패킷을 주입했을 때 비로소 성공으로 처리되는지 확인.
4. **30분 주기 테스트:** 개발 편의상 일시적으로 10초 등 짧은 주기로 타이머를 맞추어 주기적인 재시도가 이루어지는지 콘솔 로그를 통해 검증.
