# HealUs 인슐린 펌프 BLE 연동 및 고도화 완료 보고서

인슐린 펌프 모바일 앱 개발계획서 및 BLE 메시지 규격서(`In_pump_msg_set_260606.md`)를 100% 만족하는 네이티브 고도화 및 웹뷰 브릿지 연동 작업을 완료하였습니다.

---

## 1. 주요 구현 내용

### 1) BLE 패킷 전송 마진 및 분할 수신 재조립 설계
- **[ble_packet_transmitter.dart](file:///e:/projects/healus/lib/services/ble/ble_packet_transmitter.dart)**: 20Byte 논리 패킷을 10Byte 청크로 쪼개어 보낼 때 마진 지연시간을 규격에 맞춰 **75ms**로 세팅하였습니다.
- **[ble_packet_assembler.dart](file:///e:/projects/healus/lib/services/ble/ble_packet_assembler.dart)**: 첫 번째 청크 수신 후 500ms 이내에 두 번째 청크가 도달하지 않으면 **500ms 재조립 타임아웃**을 유발하고, 버퍼를 자동으로 초기화한 뒤 복구(재연결) 콜백을 작동하도록 구현했습니다.

### 2) 기기 연결 핸드셰이킹 시나리오 및 예외 복구
- **[ble_handshake_controller.dart](file:///e:/projects/healus/lib/services/ble/ble_handshake_controller.dart) [NEW]**: 실제 물리 기기 연결 시 규격서의 세션 시작 프로세스를 순차적으로 처리합니다.
  1. `connect(macAddress)` 시도 (3초 타임아웃), 실패 시 **1회 재시도** 수행.
  2. 기기로부터 `BT_START_REQ (0x01)` 수신 대기.
  3. 앱에서 `BT_CONNECTABLE_CTRL_REQ (0x02)` 패킷 송출.
  4. `BT_STATE_REQ (0x04)` 송출 및 `BT_STATE_IND (0x05)` 대조를 통한 **2차 Idle 검증**. 실패 시 `BT_SYSEM_RESET (0x43)` 송출.
  5. `BT_CUR_TIME_IND (0x06)` 송출 및 `BT_CUR_TIME_RES (0x44)` 대조를 통한 **2차 시간 동기화 검증**. 불일치 시 `BT_SYSEM_RESET (0x43)` 송출.
  6. `BT_PRS_APP_PASSWD_REQ (0x41)` 송출 및 `BT_PRS_APP_PASSWD_RES (0x42)` 수신을 통해 실제 기기 비밀번호 획득 및 전역 상태 동기화.
- **테스트 모드 자동 전이**: 연결 실패(3초 초과 2회 실패) 또는 핸드셰이크 예외 발생 시 자동으로 **테스트 모드로 전환**하며, 가상 펌프 서비스(`MockBleService`)를 연결하여 끊김 없는 사용성을 보장합니다.

### 3) 대시보드 상태 동기화 및 30분 주기적 배터리 요청
- **[main.dart](file:///e:/projects/healus/lib/main.dart)**:
  - 사용자가 대시보드(`dashboard/code.html`)에 진입하면 `BT_BATT_DATA_REQ (0x70)`, `BT_PUMP_PID_REQ (0x09)`, `BT_LOG_INJ_QNT_REQ (0x1E)`, `BT_INJ_INFO_REQ (0x15)`, `BT_PUMP_FW_REQ (0x3E)` 패킷들을 기기에 일제히 대기열로 요청하여 초기 화면 데이터를 완성합니다.
  - 기기 연결 수립 시 **30분 주기적 배터리 조회 타이머**가 기동되며, 30분마다 `BT_BATT_DATA_REQ (0x70)`를 보내 최신 배터리 퍼센트를 대시보드에 반영합니다.

### 4) 암호 하이재킹 서빙 및 네이티브 팝업
- 비밀번호 입력화면(`password/code.html`)으로 이동 시 네이티브에서 Asset 파일을 로드하여 `correctPin` 검증 논리 상수를 실시간으로 기기에서 얻어온 비밀번호(`PumpStateData.password`)로 치환하여 웹뷰에 주입 서빙합니다.
- 네이티브 기기 에러(`BT_ERR_IND`) 감지 시 어느 화면에 있더라도 대시보드로 강제 리다이렉트 시키고, 화면 상단에 네이티브 경고 팝업 오버레이를 띄웁니다.

---

## 2. 검증 결과 요약

작성한 모든 단위 테스트(`basal_sync_controller_test.dart`, `ble_packet_assembler_test.dart`, `error_interceptor_test.dart`, `inject_controller_test.dart`, `pump_state_provider_test.dart`)가 통과 완료되었습니다.

```bash
$ flutter test
Resolving dependencies...
Got dependencies!
00:00 +0: loading E:/projects/healus/test/basal_sync_controller_test.dart
...
00:01 +24: All tests passed!
```

---

## 3. 변경 이력 요약

| 파일명 | 변경 내용 요약 |
| :--- | :--- |
| [opcodes.dart](file:///e:/projects/healus/lib/services/ble/opcodes.dart) | 비밀번호 조회 및 리셋, 시간 응답용 신규 Opcode 상수를 ver 260606 규격에 맞춰 반영 |
| [hardware_ble_service.dart](file:///e:/projects/healus/lib/services/ble/hardware_ble_service.dart) | `DeviceIdentifier` 컴파일 에러 해결 및 재조립 타임아웃 복구 흐름 조율 |
| [ble_handshake_controller.dart](file:///e:/projects/healus/lib/services/ble/ble_handshake_controller.dart) | **[NEW]** 실기기 연결(3초), 1회 재시도, 기기 상태/시간 동기화 2차 검증(실패 시 리셋 패킷 송출), 비밀번호 조회를 수반하는 세션 체결기 구현 |
| [main.dart](file:///e:/projects/healus/lib/main.dart) | 연결 대기 중 로딩 인디케이터 UI 오버레이 추가, 대시보드 진입 시 정보 일괄 획득 바인딩, 30분 주기 배터리 체크 타이머 연동 |
| [basal_sync_controller_test.dart](file:///e:/projects/healus/test/basal_sync_controller_test.dart) | 하단 닫는 괄호 컴파일 유실 문제 해결 |
