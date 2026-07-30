# 운동적용(Exercise Mode) 로직 분리 및 정상화 구현 계획

요청해주신 5가지 추가 요구사항을 모두 반영한 수정된 구현 계획입니다.

## User Review Required

> [!IMPORTANT]
> 1. 앱에서 운동적용 시 0x29 패킷이 오지 않는 문제를 해결하기 위해, 앱에서 운동 명령이 펌프에 성공적으로 전달(0x00 OK 수신)되면 플러터가 자체적으로 운동 모드(isExerciseActive = true)를 강제 시작하도록 처리합니다. 펌프 조작 시에는 0x29를 받아 시작하므로 두 프로세스가 동일하게 동작합니다.
> 2. 웹뷰의 `storage` 이벤트 한계(Flutter가 직접 로컬스토리지를 변경하면 이벤트가 발생하지 않음)로 인해 그동안 펌프 동작 시 "주입 중" 배지가 실시간으로 뜨지 않던 버그를 발견했습니다. 이 통신 구조를 자바스크립트 함수 직접 호출 방식으로 개선하여 주입 및 운동 배지가 즉각 표시되도록 고칩니다.

## Proposed Changes

---

### Dart State & Backend (플러터 영역)

#### [MODIFY] `lib/state/pump_state_provider.dart`
- `PumpStateData`에 `isExerciseActive` (bool) 속성을 추가합니다.
- `0x29 (BT_EXERCISE_INJ_START_IND)` 수신 시 `isExerciseActive = true`로 변경합니다. (주입 상태와 분리)
- `0x2A (BT_EXERCISE_INJ_STOP_IND)` 수신 시 `isExerciseActive = false`로 변경합니다.
- `setExerciseActive(bool active)` 액션 메서드를 추가하여 앱 내에서 수동으로 켤 수 있게 합니다.

#### [MODIFY] `lib/main.dart`
- **명령 성공 시 강제 상태 변경:**
  - `_handleConsoleMessage`의 `SEND_EXERCISE_COMMAND` 처리부에서 BLE 전송이 성공(`success == true`)하면, `ref.read(pumpStateProvider.notifier).setExerciseActive(true);` 를 호출하여 0x29 패킷이 오지 않아도 상태를 동기화합니다.
- **웹뷰 동기화 방식 개선:**
  - 기존의 `localStorage.setItem(...)` 방식 대신, `_controller.runJavaScript("if(window.onPumpStateChanged) window.onPumpStateChanged(${isInjecting}, ${isExerciseActive});")` 처럼 웹뷰의 JS 함수를 직접 호출하여 상태를 실시간으로 밀어넣습니다.
- **운동 종료 토스트:**
  - `wasExerciseActive == true && isExerciseActive == false` 인 경우, `_controller.runJavaScript("if(typeof showToast === 'function') showToast('운동 설정 적용 시간이 종료되었습니다.');")` 를 실행합니다.

---

### Frontend UI & JS (웹뷰 영역)

#### [MODIFY] `ui_design/dashboard/code.html`
- **배지 추가:** 상단의 "주입 중" 배지(`badge-injecting`) 옆에 "운동 감량 중" 배지(`badge-exercise`)를 녹색(`bg-green-100 text-green-600`)으로 새로 추가합니다.
- **상태 업데이트 함수 (`onPumpStateChanged`) 신설:**
  - 플러터에서 직접 호출할 수 있는 `window.onPumpStateChanged(isInjecting, isExercise)` 함수를 만들어 배지 노출 상태를 즉각 갱신합니다.
  - 이로써 펌프 조작 시에도 "주입 중" 배지와 "운동 감량 중" 배지가 즉각적으로 나타나게 됩니다.
- **버튼 차단 분리:**
  - `navigateToAction()` 함수 수정:
    - `isInjecting`이 `true`이면 기존처럼 모든 버튼(주입, 운동 등)을 차단하고 토스트 발생.
    - `isExerciseActive`가 `true`일 때 `actionKey === 'exercise'`(운동 버튼)를 누르면 "운동 적용 중입니다" 토스트를 띄우고 차단합니다. 다른 버튼(식사/추가 등)은 차단하지 않습니다.
- **찌꺼기 정리:**
  - `handleCompleteConfirm()` 등에 `localStorage.removeItem('lastInjectAction')`를 추가하여 모달의 텍스트 오류(엉뚱한 주입에 "운동완료"가 뜨는 현상)를 방지합니다.

## Verification Plan

### Manual Verification
1. **앱에서 운동적용 테스트:**
   - 앱 조작으로 운동 적용(0x13 송신 -> 0x00 수신) 후, 0x29가 없어도 "운동 감량 중" 배지가 뜨고 운동 버튼이 먹통이 되는지 확인. 식사 버튼은 정상 작동 확인.
2. **펌프에서 운동적용 테스트:**
   - 펌프 조작으로 운동 적용(0x29 수신) 시 대시보드에 즉각 "운동 감량 중" 배지가 뜨는지 확인.
   - 0x2A 수신 시 "운동 설정 적용 시간이 종료되었습니다." 라는 토스트가 기존 디자인과 똑같이 나오는지 확인.
3. **펌프에서 주입 테스트 (버그 픽스):**
   - 펌프 조작으로 식사주입(0x27 수신) 시 대시보드에 "주입 중" 배지가 정상적으로 뜨는지 확인. (기존 스토리지 이벤트 버그 수정 테스트)
