# 대시보드 리다이렉션 시 주입 완료 멀티모달 팝업 누락 버그 해결 계획서

본 계획서는 주입 완료(정상 수신 및 타임아웃 지연 완료) 후 대시보드 화면(`dashboard/code.html`)으로 이동할 때, 웹뷰 로딩 생명주기 타이밍 이슈로 인해 "주입이 완료되었습니다" 멀티모달 팝업이 출력되지 않던 문제를 해결하는 방안을 다룹니다.

## User Review Required

> [!IMPORTANT]
> - **버그 원인 분석**:
>   - 기존 코드에서는 `loadFlutterAsset` 비동기 동작이 끝난 후에 `localStorage`를 업데이트하였습니다.
>   - 이로 인해 대시보드가 새로 로드되면서 `DOMContentLoaded` 리스너가 이미 실행되어 스토리지를 감시하는 조건이 끝난 이후에 데이터가 주입되어 팝업이 누락되었습니다.
> - **해결 설계안**:
>   1. 대시보드로 화면을 이동하기 **직전**에 웹뷰 콘솔을 통해 `localStorage` 상태(`isInjecting = false`, `showCompleteModal = true`)를 먼저 업데이트합니다.
>   2. 대시보드로 이동 완료(`loadFlutterAsset` 완료)된 `.then` 콜백 시점에 추가로 명시적 JS 함수 `window.openModal('complete')`를 강제 호출하여 팝업 누락을 이중 방어합니다.
>   3. 이미 대시보드에 있는 상태에서 완료되었을 때도 팝업 함수가 지체 없이 다이렉트로 실행되도록 흐름을 보정합니다.

---

## Proposed Changes

### Hybrid App Container (Flutter WebView Layer)

---

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)

- `ref.listen(pumpStateProvider, ...)` 내의 주입 종료 핸들러 및 타임아웃 타이머 만료 콜백 코드 수정:
  - **3초 타임아웃 만료 시 (5초 대기 후)**:
    - 리다이렉트 전: `localStorage.setItem('isInjecting', 'false')`, `localStorage.setItem('showCompleteModal', 'true')` 설정.
    - 리다이렉트 후: `.then((_) { ... })` 내에서 `window.openModal('complete')` 강제 실행.
    - 이미 대시보드에 있을 때: 스토리지 업데이트 및 `window.openModal('complete')` 즉시 실행.
  - **정상 완료 패킷 수신 시**:
    - 동일하게 리다이렉트 전에 스토리지 설정을 완료하고, 이동 후 `window.openModal('complete')`를 강제 호출하도록 통일.

---

## Verification Plan

### Automated Tests
- `flutter test`를 수행하여 리다이렉션 수정 후에도 기존 통신 및 상태 테스트 수트 24개가 깨지지 않는지 검증합니다.

### Manual Verification
1. 에뮬레이터에서 주입을 기동하여 3초 타임아웃을 유발합니다.
2. 테스트 모드 전환 후 5초간 대기하다가 대시보드로 복귀했을 때, 화면에 `"주입이 완료되었습니다"` (OK 버튼만 존재하는 형태) 멀티모달이 정상적으로 팝업되는지 확인합니다.
3. 주입 도중 다른 화면(설정, 기록 등)으로 이동했다가 타임아웃이 발생했을 때도 대시보드로 정상 이동하며 완료 팝업이 활성화되는지 최종 확인합니다.
