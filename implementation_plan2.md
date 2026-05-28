# 웹뷰 UI 오동작 수정 및 비례 스케일링 최적화 구현 계획

본 계획서는 WebView 상에서 발생하던 대시보드 네비게이션/탭바 잘림 현상, 식사주입 페이지 버튼 위치 이탈(공중 부양) 오류, 백 버튼 및 리프레쉬 버튼 미작동 문제를 완벽히 해결하기 위한 아키텍처 개선안을 정의합니다.

## User Review Required

> [!IMPORTANT]
> - **Body scale 방식 전환 (안정성 증대)**: 이전 방식인 DOM 트리를 임의로 변경하여 래핑하는 방식은 React의 마운팅 노드 관계와 `fixed` 레이아웃 배치를 파괴하는 부작용이 있어, 이를 폐기하고 `body` 엘리먼트에 직접 `CSS transform: scale`을 가하는 방식으로 수정합니다. 이를 통해 원본 레이아웃의 완전한 비례가 100% 안전하게 유지됩니다.
> - **안드로이드 시스템 백 버튼 지원**: 에뮬레이터 및 실기기에서 백 버튼 입력 시 앱이 즉시 종료되지 않고, 웹뷰 내에서 이전 페이지가 존재하면 뒤로가기(`goBack()`)를 실행하도록 보장합니다.

## Proposed Changes

### [UI and Application Core]

#### [MODIFY] [lib/main.dart](file:///e:/projects/healus/lib/main.dart)
- **비례 줌/스케일링 로직 개편**:
  - `html`은 100% 고정하고, `body` 자체에 `transform-origin: top center`를 부여합니다.
  - 각 화면의 HTML 코드에 작성되어 있는 원래 `body` 크기(예: 대시보드 390x884, 식사주입 393x852)를 자동으로 탐색/파싱하여 기준 너비/높이로 활용합니다.
  - 기기 비율에 비례하여 `body` 크기와 `scale(...)` 값을 계산한 뒤 정중앙에 수평 정렬(`left: 50%`, `translateX(-50%)`) 처리합니다. 이로써 탭바 및 버튼 등의 구성요소 위치가 절대 틀어지지 않습니다.
- **리프레쉬(새로고침) 버튼 연동**:
  - HTML 내 새로고침 버튼(`#btn-refresh`)에 기존 단순 애니메이션 효과 외에, `window.location.reload()` 동작을 바인딩하는 스크립트를 추가 주입합니다.
- **안드로이드 시스템 뒤로가기(Back Button) 제어**:
  - `main.dart` 상단에 `package:flutter/services.dart`를 임포트합니다.
  - `WebViewHomeScreen`의 `Scaffold`를 `PopScope` 위젯으로 감싸고, `onPopInvokedWithResult`를 활용해 웹뷰 히스토리가 있으면 `canGoBack/goBack`을 수행하고, 없으면 앱을 안전하게 종료(`SystemNavigator.pop()`)하도록 구현합니다.

---

## Verification Plan

### Automated/Manual Tests
- **에뮬레이터 구동 및 검증**:
  - `flutter run` 세션 핫 리스타트 후, 최초 화면부터 대시보드, 식사주입, 설정 등 다양한 페이지로 전환해 봅니다.
  - **네비게이션바/탭바 잘림 검증**: 대시보드의 상단 바 및 하단 탭바가 기기 하단에 이쁘게 안착하여 잘리지 않고 나오는지 검증합니다.
  - **식사주입 버튼 위치 검증**: 식사주입 페이지 하단의 "주입하기" 및 "닫기" 버튼이 화면 밑단에 정확하게 비례 정렬되어 나오는지 확인합니다.
  - **작동성 테스트**: 에뮬레이터 내에서 시스템 백(Back) 버튼 클릭 시 이전 웹 페이지로 정상 복귀하는지, 대시보드의 리프레쉬(Refresh) 버튼 클릭 시 웹뷰 화면이 정상적으로 새로고침되는지 검증합니다.
