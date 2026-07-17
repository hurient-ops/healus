# 가상 BLE 완료 패킷 방출 기반 주입 완료 시뮬레이션 구현 계획서

본 계획서는 주입 중 상태에서 실제 완료 패킷(`0x3B`)이 수신되지 않을 때, 3초 타임아웃 감지 후 테스트 모드로 전환하여 5초 후에 가상의 `BT_INJ_STOP_IND(0x3B)` 패킷을 네이티브 상에서 직접 트리거(방출)함으로써, 정상 패킷 수신 흐름을 모사하여 대시보드 리다이렉트 및 주입완료 멀티모달이 정상 작동하도록 설계하는 방안을 다룹니다.

## User Review Required

> [!IMPORTANT]
> - **가상 BLE 완료 이벤트 트리거 동작 원리**:
>   - 3초 동안 완료 패킷이 유입되지 않으면 자동으로 테스트 모드로 스위칭(`testModeProvider = true`)합니다.
>   - 테스트 모드 진입 후 5초 대기 타이머가 동작합니다.
>   - 5초 만료 시점에 `MockBleService` 내부에 구현할 퍼블릭 메서드(`fireFakeStopPacket()`)를 호출하여 가상의 `BT_INJ_STOP_IND(0x3B)` 완료 패킷을 수신 패킷 스트림으로 방출합니다.
>   - 방출된 패킷은 실제 기기에서 정상 완료된 것처럼 수신 리스너를 거쳐 `pumpStateProvider` 상태를 바꾸고, 기존에 완벽히 구현된 정상 완료 흐름을 통해 웹뷰 락 해제, 대시보드 리다이렉션, 완료 팝업 실행이 순차 작동하도록 합니다.
> - **추후 테스트 모드 관련 코드 삭제 용이성**:
>   - `lib/main.dart` 내의 타이머 감시 로직 및 `MockBleService` 내의 가상 패킷 방출 메서드를 `// === [TEST MODE ONLY] ===` 주석으로 완전 격리하여 개발합니다.

---

## Proposed Changes

### Communication & Simulated Service Layer

---

#### [MODIFY] [mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)

- `MockBleService` 클래스 내부에 가상 주입완료 패킷 방출용 퍼블릭 메서드 추가:
  - `void fireFakeStopPacket()`:
    - 주입 종류 `0x02` (식사 주입 완료 모사), 현재 시간 DATE 포맷팅, 주입량(`100` = 1.00U), 남은 인슐린 양을 데이터 페이로드(11Byte)로 포장하여 가상의 `0x3B` 20Byte 패킷을 생성합니다.
    - `_fireFakeIncomingPacket(Opcodes.btInjStopInd, stopData)`를 호출하여 수신 패킷 스트림으로 강제 방출합니다.

---

### Hybrid App Container (Flutter WebView Layer)

---

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)

- 이전 턴에서 지저분하게 작성했던 강제 리다이렉트 로직(`_pendingShowCompleteModal` 관련 플래그, `loadFlutterAsset` 완료 후 자바스크립트 강제 팝업 주입 등)을 전면 **롤백 및 삭제**하여 구조를 복원합니다.
- `ref.listen(pumpStateProvider, ...)` 내의 주입 개시 시점 3초 감시 및 5초 지연 테스트 모드 트리거 로직을 구현합니다:
  - 3초 타임아웃 발생 시:
    1. 테스트 모드 활성화: `ref.read(testModeProvider.notifier).state = true;`
    2. 웹뷰에 테스트 모드 동기화 수행.
    3. `_mockWaitTimer`를 5초 후 동작하도록 기동.
  - 5초 지연 대기 만료 시:
    1. `ref.read(bleServiceProvider)` 인스턴스 획득.
    2. 해당 인스턴스가 `MockBleService` 타입이면 `fireFakeStopPacket()` 메서드를 호출하여 가상 패킷 `0x3B`를 강제 트리거합니다.

---

## Verification Plan

### Automated Tests
- `flutter test`를 돌려 기존 24개 통신/설정 단위 테스트 스위트가 여전히 100% 정상 작동하는지 확인합니다.

### Manual Verification
1. 에뮬레이터에서 주입을 기동하여 완료 메시지가 3초간 수신되지 않도록 유도합니다.
2. 3초 경과 후 테스트 모드로 정상 진입하고 5초간 대기하는지 확인합니다.
3. 5초가 지난 시점에 가상 완료 패킷 방출로 인해 화면이 자동으로 대시보드로 이동하고 `"주입 요청을 하였습니다"` 아래에 OK 버튼이 중앙 정렬된 완료 팝업(멀티모달)이 정상 노출되는지 최종 검토합니다.
