# 주입 전 상태 확인 로직 적용 계획

요청하신 프롬프트 내용에 따라 인슐린 주입 전 펌프의 `idle` 상태를 선행 확인하는 보호 로직을 구현합니다.

## User Review Required

> [!IMPORTANT]
> **스낵바(Toast) 구현 방식 관련:** `Fluttertoast` 외부 패키지를 추가하는 대신 앱 전역에서 팝업을 띄울 수 있도록 Flutter 기본 제공 `ScaffoldMessenger`를 전역 키(GlobalKey)로 연결하여 스낵바를 표시하려고 합니다. 이는 패키지 종속성을 줄이고 깔끔하게 구현할 수 있는 권장 방식입니다. 승인해 주시면 이 방식으로 진행하겠습니다.

## Open Questions

> [!NOTE]
> `BT_STATE_IND`의 응답 Opcode를 `0x04` 또는 `0x05` 모두 허용하도록 구현할 예정입니다. 또한, 상태 값이 `idle(0x01)`일 때만 정상 주입 패킷이 큐에 들어가게 됩니다.

## Proposed Changes

---

### Handshake 로직 제거
#### [MODIFY] [ble_handshake_controller.dart](file:///e:/projects/healus/lib/services/ble/ble_handshake_controller.dart)
- `connectAndHandshake` 내에서 `BT_STATE_REQ(0x04)`를 전송하고 `BT_STATE_IND`를 기다리던 구문(및 시스템 리셋 로직)을 제거합니다.

---

### 전역 UI 표시를 위한 Global Key 도입
#### [NEW] [globals.dart](file:///e:/projects/healus/lib/globals.dart)
- 앱 어디서든 스낵바를 띄울 수 있게 `rootScaffoldMessengerKey`를 정의합니다.
#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- `MaterialApp`에 `scaffoldMessengerKey: rootScaffoldMessengerKey`를 연결합니다.

---

### 비동기 상태 확인 및 조건부 패킷 전송 로직 추가
#### [MODIFY] [inject_controller.dart](file:///e:/projects/healus/lib/services/inject/inject_controller.dart)
- `Future<void> checkStateAndExecute(List<int> targetPacket)` 메서드를 추가합니다.
- `bleService.receivedPacketsStream`을 구독하여 `BT_STATE_REQ(0x04)` 송신 후,
  1. `BT_MSG_RES(0x00)` 수신 대기 (Opcode 일치 여부 확인)
  2. 연달아 `BT_STATE_IND(0x04 또는 0x05)` 수신 대기
- `ref.read(timeoutHoldProvider)`를 확인하여 Hold 상태일 땐 365일, 아닐 땐 3초로 타임아웃을 설정합니다.
- 최종 `IND`의 상태 값이 `0x01(idle)`이면 `queuePacket(targetPacket)`을 실행합니다.
- 타임아웃 되거나 `idle`이 아닐 경우 `rootScaffoldMessengerKey`를 통해 "주입 요청을 취소합니다." 스낵바를 표시합니다.

---

### WebView 명령 핸들러 변경
#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- 자바스크립트 메시지 핸들러에서 주입/적용 명령이 들어왔을 때 기존의 `queuePacket()` 직접 호출 대신 `injectNotifier.checkStateAndExecute(packet)`를 호출하도록 수정합니다. (식사 주입, 추가 주입, 회식 적용, 운동 적용 부분)

## Verification Plan

### Manual Verification
- 가상 BLE 수동 제어 패널에서 "타임아웃 일시정지 (Hold)"를 켭니다.
- 식사 주입 버튼을 누릅니다.
- 앱이 무한 대기하는지 확인합니다.
- 수동 패널에서 `0x00` 응답과 `0x05` (상태값 0x01) 패킷을 순서대로 모사 전송합니다.
- 앱이 비로소 `0x17` 주입 패킷을 정상 전송하는지 확인합니다.
- 만약 `0x05` 상태값이 `0x02` 등 다른 값이면 스낵바가 뜨고 주입 패킷이 전송되지 않는지 확인합니다.
