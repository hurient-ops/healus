# 주입 미완료 시 테스트 모드 전이 및 5초 대기 후 대시보드 리다이렉션 구현 계획서

본 계획서는 주입 중 상태에서 정상적인 주입완료 메시지(`BT_INJ_STOP_IND`, `0x3B`)가 수신되지 않는 장애 상황 발생 시, 자동으로 테스트 모드로 진입하고 5초간 대기한 뒤 대시보드로 이동하여 완료 팝업을 띄우는 격리된 안전 제어 흐름 설계안을 다룹니다.

## User Review Required

> [!IMPORTANT]
> - **주입 완료 타임아웃 기준 시간**:
>   - 주입 시작 패킷(`0x3A`) 수신 후 정상 완료 패킷(`0x3B`)이 들어와야 하는 임계 대기 시간(타임아웃)을 **10초**로 설정합니다.
>   - 10초 이내에 `0x3B`가 수신되지 않을 경우, 기기 데이터 통신 이상으로 판정하여 실제 BLE 세션을 강제 이탈하고 테스트 모드로 전환합니다.
> - **테스트 모드에서의 5초 추가 지연**:
>   - 테스트 모드 전환 직후 5초간 지연(대기) 타이머가 작동합니다. 이 시간 동안은 주입 중 레이아웃이 유지됩니다.
>   - 5초 만료 시점에 어느 페이지에 있더라도 대시보드 화면(`dashboard/code.html`)으로 강제 이동하고 주입 완료 멀티모달이 팝업됩니다.
> - **추후 테스트 모드 관련 코드 삭제 용이성**:
>   - 이 기능은 `lib/main.dart` 내부의 `_WebViewHomeScreenState` 클래스 내에 `// === [TEST MODE ONLY] ===` 주석 영역으로 완전 격리 설계하여, 추후 상용 릴리즈 시 해당 주석 영역만 손쉽게 일괄 제거할 수 있도록 처리합니다.

---

## Proposed Changes

### Hybrid App Container (Flutter WebView Layer)

---

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)

- `_WebViewHomeScreenState` 상태 클래스 내부에 타이머 변수 추가:
  - `Timer? _injectTimeoutTimer;` (실기기 주입 대기 10초 감시용)
  - `Timer? _mockWaitTimer;` (테스트 모드 진입 후 5초 대기용)
- `dispose()` 생명주기 메서드에 위 타이머들을 안정적으로 `cancel()` 처리하는 코드 추가.
- `ref.listen(pumpStateProvider, ...)` 내에서 주입 상태 변경 감지 시 타이머 제어 탑재:
  - 주입 시작 (`isPumpInjecting`이 `false` -> `true` 전이 시):
    - `_injectTimeoutTimer`를 10초 후 작동하도록 작동 기동.
  - 주입 정상 종료 (`isPumpInjecting`이 `true` -> `false` 전이 시):
    - `_injectTimeoutTimer?.cancel()` 및 `_mockWaitTimer?.cancel()` 수행.
- **테스트 모드 자동 전이 및 5초 대기 시퀀스** 구현 (`// === [TEST MODE ONLY] ===` 영역 내):
  - 10초 주입 타임아웃 발생 시:
    1. 테스트 모드 플래그 활성화: `ref.read(testModeProvider.notifier).state = true;`
    2. 웹뷰에 테스트 모드 동기화 수행.
    3. `_mockWaitTimer`를 5초 후 동작하도록 기동.
  - 5초 지연 대기 만료 시:
    1. 네이티브 주입 상태를 완료 처리: `ref.read(pumpStateProvider.notifier).setInjecting(false);`
    2. 어느 화면에 있더라도 `dashboard/code.html`로 웹뷰 강제 리다이렉트 실행.
    3. 웹뷰 `localStorage`에 `isInjecting = false`, `showCompleteModal = true` 설정 주입하여 완료 모달 팝업 유도.

---

## Verification Plan

### Automated Tests
- `inject_controller_test.dart` 등 기존 24개 단위 테스트를 실행하여 신규 타이머 로직 추가 후에도 빌드 및 주요 BLE 수신 동작이 파괴되지 않는지 확인합니다.
  - 실행 명령어: `flutter test`

### Manual Verification
1. 에뮬레이터에서 앱을 구동하고 실제 BLE 기기 미연결 상태(혹은 주입 완료 메시지 미수신 시나리오 모사)로 둡니다.
2. 식사 주입 또는 추가 주입 화면으로 진입하여 주입 버튼을 터치해 주입 상태를 활성화시킵니다.
3. 임계 대기 시간인 10초 동안 완료 메시지가 수신되지 않을 때, 앱 내부적으로 `testModeProvider`가 `true`로 활성화되는지 관찰합니다.
4. 테스트 모드 진입 이후 5초 동안 상태가 유지(대기)되는지 확인합니다.
5. 5초 대기가 끝난 직후 어느 페이지에 머무르고 있었든 상관없이 자동으로 대시보드로 복귀하며 `"주입 요청을 하였습니다"` 완료 모달이 팝업되는지 확인합니다.
