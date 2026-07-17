# 화면 해상도 비례 스케일링 기반 반응형 구현 계획

본 계획서는 `./ui_design` 웹 리소스의 원본 디자인 비율(390px x 884px)을 그대로 유지하면서, 모바일 기기의 가로/세로 해상도에 맞춰 가장 적절한 크기로 비례해서 변하는(CSS Scale 기법) 반응형 레이아웃 고도화 방안을 정의합니다.

## User Review Required

> [!IMPORTANT]
> - **비례 축척(Scale) 방식 적용**: 화면 너비나 높이가 늘어날 때 컴포넌트가 양옆으로 비정상적으로 길어지거나 탭바가 하단으로 밀려 나가는 대신, 디자인 원본의 종횡비를 그대로 유지한 채 화면에 꼭 들어맞도록 확대/축소됩니다.
> - **레이아웃 깨짐 원천 방지**: 원본 HTML 코드에 지정되어 있는 고정 수치 구조를 억지로 늘리지 않고 전체 페이지 노드를 컨테이너로 감싸 비례 확대하므로, 화면이 찌그러지거나 글자가 겹쳐지는 문제를 완벽히 해결합니다.

## Proposed Changes

### [UI and Application Core]

#### [MODIFY] [lib/main.dart](file:///e:/projects/healus/lib/main.dart)
- `WebViewController`의 `onPageFinished` 메서드 내부의 자바스크립트 주입 코드를 **비례 스케일 래퍼 기법**으로 전면 개편합니다.
- **구현 메커니즘**:
  1. 페이지가 로드되면 `body` 내부의 기존 엘리먼트들을 390px x 884px의 고정 크기를 가진 고유 래퍼 엘리먼트(`#responsive-wrapper`) 내로 일괄 이동시킵니다.
  2. 기기의 가로폭(`window.innerWidth`)과 세로폭(`window.innerHeight`)을 실시간 측정하여, 두 비례 인수(`scaleX = width / 390`, `scaleY = height / 884`) 중 기기 화면을 벗어나지 않는 최적의 비례 스케일 값(`Math.min(scaleX, scaleY)`)을 자동 산출합니다.
  3. `#responsive-wrapper`에 `transform: scale(scale)` 및 `transform-origin: center center` 속성을 부여하여 기기 화면 정중앙에 이쁜 비율로 비례 렌더링을 고정합니다.
  4. 윈도우 `resize` 이벤트를 등록하여 디바이스 방향 전환이나 해상도 변화에도 실시간 대응되도록 처리합니다.

---

## Verification Plan

### Automated/Manual Tests
- **에뮬레이터 구동 및 핫 리스타트**: `lib/main.dart` 파일 수정 반영 후 에뮬레이터에서 앱을 재구동합니다.
- **다양한 기기 대응 시뮬레이션**: 세로폭이 넓은 Pixel 9 Pro XL 화면의 한가운데에 390x884 비율의 원본 디자인 레이아웃이 정교한 스케일 확대를 거쳐 화면에 알맞게 들어차는지 시각적으로 캡처 확인합니다.
- **비례 렌더링 확인**: 화면 하단 탭바(`nav`) 및 상단 바가 화면 밖으로 넘치거나 어긋나지 않고 딱 맞게 보이는지 검증합니다.
