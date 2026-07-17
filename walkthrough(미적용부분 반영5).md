# UI 및 기능 보완 구현 계획서 (대시보드 상태 보존, 히스토리 그래프 정렬, 비밀번호 동기화 개선)

HealUs 앱에서 발생하는 대시보드 상태 롤백, 히스토리 그래프 눈금 정렬 및 스케일 불일치, 그리고 가상 비밀번호 패킷 미반영 문제를 구조적으로 수정합니다.

## User Review Required

> [!IMPORTANT]
> 이번 수정은 네이티브 코드(Dart)와 웹뷰 내부 HTML/JS 간의 데이터 연동 구조를 강화합니다. 변경 시 에뮬레이터 재설치가 필요할 수 있습니다.

## Proposed Changes

### [Native UI & Webview Integration]

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
* **대시보드 상태 지속 보존**: `_syncStateToWebview()` 실행 시 단순히 DOM Element를 바꾸는 것에 그치지 않고, `localStorage`에 `basalSum`, `mealSum`, `appendSum`, `batteryLevel`, `insulinRemaining`의 최종 수신 값을 무조건 저장(setItem)하도록 코드를 보강합니다.
* **히스토리 진입 시 즉시 동기화**: `onPageFinished` 이벤트 내에서 `history/code.html` 페이지 진입을 감지하면 즉시 기기에 이력 로그 요청(`btLogReq`, `0x1D`)을 전송하고 로컬 DB 이력을 다시 읽어 웹뷰로 즉시 푸시하도록 코드를 추가합니다.
* **비밀번호 하이재킹 치환 매칭 개선**: 띄어쓰기 인덴테이션 오차로 인해 비밀번호 치환에 실패하지 않도록 `"correctPin = '000000'"` 전체 키워드로 치환 범위를 안전하게 단순화합니다.

#### [MODIFY] [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
* **비밀번호 수신 파싱 수정**: 수신된 비밀번호 패킷을 아스키로 정확히 해석할 수 있게 `String.fromCharCodes(passwordBytes).trim()` 방식을 빈틈없이 유지합니다.

---

### [Webview Screens]

#### [MODIFY] [dashboard code.html](file:///e:/projects/healus/ui_design/dashboard/code.html)
* **초기 로드 시 localStorage 복원**: 다른 화면으로 이동했다 돌아올 때(웹뷰 새로고침 시) 순간적으로 하드코딩된 초기값으로 롤백되지 않도록, `DOMContentLoaded` 직후 `localStorage`에 저장되어 있던 실시간 데이터(`basalSum`, `mealSum`, `appendSum`, `batteryLevel`, `insulinRemaining`)를 읽어와 초기 상태로 세팅하도록 수정합니다.

#### [MODIFY] [history code.html](file:///e:/projects/healus/ui_design/history/code.html)
* **y축 눈금 및 격자선 1:1 수평 매칭 정렬**: Y축 눈금(0~100) 텍스트와 차트 내 수평선 격자를 `position: absolute`와 퍼센티지 (`top: 0%`, `top: 20%` 등)를 이용한 절대 좌표 구조로 개편하여 정확하게 수평 일치시킵니다.
* **눈금 0의 위치 정밀 조정**: 0 눈금이 막대그래프 하단 및 테두리선(`border-b`)과 완벽히 겹치도록 정밀하게 맞춥니다.
* **추가주입 스케일 통일**: `buildSeries` 에서 그래프 기둥을 그릴 때 저녁 식사량 필드(`evening_total`)를 매핑해 오던 논리적 오류를 수정하여 표 데이터와 동일한 추가주입량 필드(`append_total`)를 참조하도록 개선합니다.
* **그래프 갱신 지속성**: 네이티브에서 전송해 주는 이력 정보(`receiveBleHistoryLogs`)와 `localStorage` 간의 데이터 흐름을 일원화하여 페이지 이동 시 렌더링 그래프가 달라지지 않도록 빌드 과정을 견고히 다듬습니다.

## Verification Plan

### Automated Tests
* 코드 수정 후 `npx tsc --noEmit`을 실행하여 TypeScript 타입 오류가 없는지 다시 한번 진단합니다.
* `flutter build apk --debug`를 기동하여 빌드가 성공적으로 완수되는지 확인합니다.

### Manual Verification
* 안드로이드 스튜디오 에뮬레이터에서 앱을 구동하고 다음을 확인합니다:
  1. 비밀번호 입력 화면에서 변경된 패스워드로 인증 성공 및 홈 진입 여부.
  2. 홈 대시보드에서 수신 정보를 확인 후, 설정/기록 화면으로 넘어갔다 돌아와도 이전 값이 그대로 잘 유지되는지 검증.
  3. 기록 화면(히스토리) 진입 시 `BT_LOG_REQ` 로그 요청이 정상 송출되며, y축의 눈금(0, 20, 40, 60, 80, 100) 및 실선 격자가 일자로 예쁘게 일치하는지 여부 확인.
  4. 그래프 하단 테이블의 수치와 막대의 실제 높이 스케일이 일치하는지 대조.
