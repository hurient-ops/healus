# 웹뷰와 상태 확인(0x04) 비동기 동기화 수정 계획

현재 인슐린 펌프 앱은 웹뷰(JS)에서 '주입하기' 등을 누르면 Flutter로 메시지를 보내고, 웹뷰는 결과를 기다리지 않고 곧바로 '주입 중...' 화면으로 전환해버리는 문제가 있습니다. 이로 인해 Flutter 쪽에서 상태 확인(0x04) 패킷을 보내고 응답을 기다리는 동안, 사용자는 이미 웹뷰가 진행되었다고 착각하게 되며, 상태가 `idle(0x01)`이 아닐 때 취소되더라도 웹뷰는 계속 '주입 중...'에 머물게 됩니다.

## User Review Required
이 계획은 웹뷰의 Javascript 코드와 Flutter의 메시지 처리 코드를 모두 수정하여, 상태 확인이 완전히 끝난 뒤에만 웹뷰 화면이 넘어가도록 보완합니다.

## Proposed Changes

### `lib/services/inject/inject_controller.dart`
- `checkStateAndExecute` 메서드의 반환 타입을 `Future<bool>`로 변경합니다. (성공 시 `true`, 실패/타임아웃 시 `false` 반환)
- `requestInjection` 메서드 또한 `Future<bool>`을 반환하도록 수정하여 호출부가 결과를 기다릴 수 있게 합니다.

### `lib/main.dart`
- 웹뷰 컨트롤러(`_controller`)에서 메시지(예: `SEND_MEAL_INJECTION_COMMAND`)를 수신했을 때 `await`를 통해 `requestInjection` 및 `checkStateAndExecute`의 결과를 기다립니다.
- 결과가 `true`일 경우, `_controller.runJavaScript("if (window.onInjectionApproved) window.onInjectionApproved();")`를 호출하여 웹뷰에 승인을 알립니다.
- 결과가 `false`일 경우, `_controller.runJavaScript("if (window.onInjectionRejected) window.onInjectionRejected();")`를 호출하여 웹뷰에 거절을 알립니다.

### `ui_design/dashboard/code.html`
- `handleRequestAccept()` 함수에서 즉시 화면을 '주입 중...'으로 넘기지 않고, 버튼의 텍스트를 "상태 확인 중..."으로 변경하고 클릭을 막는 등 대기 상태로 만듭니다.
- `window.onInjectionApproved()` 함수를 추가하여, 이 함수가 호출되면 모달을 닫고 '주입 중...' 화면으로 정상 전환되도록 합니다.
- `window.onInjectionRejected()` 함수를 추가하여, 이 함수가 호출되면 대기 상태를 풀고 "주입이 취소되었습니다" 등의 토스트 메시지를 표시하도록 합니다.

## Verification Plan
1. 에뮬레이터에서 '식사 주입'을 클릭하고 수치를 입력 후 '주입하기' 버튼을 누릅니다.
2. "주입을 진행하시겠습니까?" 모달에서 '주입하기'를 누르면, 웹뷰가 즉시 넘어가지 않고 잠시 기다리는 것을 확인합니다.
3. Flutter 측에서 0x04를 보내고 0x01(idle) 응답을 정상적으로 수신하면, 웹뷰가 '주입 중...' 화면으로 전환되는지 확인합니다.
4. 만약 '가상 BLE 제어 패널'에서 '타임아웃 일시정지'를 걸어두어 타임아웃이 발생하거나, 상태가 0x01이 아닌 경우, 웹뷰가 '주입 중...' 화면으로 넘어가지 않고 기존 화면을 유지하는지 확인합니다.
