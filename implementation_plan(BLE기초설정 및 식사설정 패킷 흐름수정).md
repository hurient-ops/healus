# BLE 기초 설정 및 식사 설정 패킷 흐름 수정 계획

사용자님의 요청에 따라, `BleMutex` 큐의 응답 대기 로직을 정교하게 제어하여 1:1 Flow가 완벽히 동작하도록 개선하는 계획입니다.

## User Review Required

> [!IMPORTANT]  
> 이전에 적용된 `BleMutex` 전역 큐 시스템 덕분에, 단순히 `inject_controller`의 큐에 연속으로 패킷을 넣기만 하면 순서대로 송수신이 보장됩니다. 따라서 `0x0F`와 `0x10`을 각각 6번, 3번 큐에 일괄 적재(queuePacket)하고, `inject_controller`가 각각에 대해 `0x12`를 기다리도록 처리하면 가장 깔끔하고 안정적인 구조가 됩니다. 

## Proposed Changes

### `lib/services/inject/inject_controller.dart`

#### [MODIFY] inject_controller.dart
- `_getExpectedResponse(int requestOpcode)` 함수 수정:
  - `Opcodes.btTimeBaseSetReq` (0x0F) -> `Opcodes.btSetRes` (0x12) 반환
  - `Opcodes.btMealSetReq` (0x10) -> `Opcodes.btSetRes` (0x12) 반환
- `_processQueue()` 내부 수신 리스너 수정:
  - `expectedOpcode`가 `Opcodes.btBaseValueRes` (0x30)인 경우, 무조건 완료(complete) 처리하지 않고 **3번째 바이트(`packet[3]`)가 `0x03`일 때만 완료 처리**하여 3번의 수신을 모두 대기하도록 변경합니다.

### `lib/services/sync/basal_sync_controller.dart`

#### [MODIFY] basal_sync_controller.dart
- `sync24hBasalSettings` 함수 최적화:
  - 기존에는 자체적으로 `_basalAckCompleter`를 사용하여 응답을 기다렸으나, 이제 `inject_controller`의 `BleMutex`가 각 패킷마다 `0x12`를 기다려주므로, 자체 대기 로직을 제거하고 **6개의 0x0F 패킷을 일괄 큐(Queue)에 적재**하기만 하도록 단순화합니다.

### 기타 참고 사항
- `BT_SET_RES` (0x12) 수신 시 인슐린 잔량 갱신 로직은 이미 `pump_state_provider.dart`의 `194라인 ~ 208라인`에서 `packet[9]`, `packet[10]`을 읽어 전역 상태를 업데이트하도록 적용되어 있으므로 별도로 수정하지 않고 그대로 유지합니다.

## Verification Plan

### Automated Tests
- `flutter build apk --release` 빌드를 통해 컴파일 오류 검증.

### Manual Verification
- 식사 설정 및 기초 설정 진입 시 펌프와 연결하여 각 3회/6회 패킷이 정확하게 `0x00 -> 0x12` 흐름을 한 묶음으로 처리하며 전송되는지 ADB 로그 확인.
