# 추가 요구사항 구현 계획서 (수정안 2)

사용자의 피드백을 반영하여 인슐린 잔량의 자체 계산 감산을 완전히 배제하고, 히스토리 화면의 값이 없는 월/일의 표기를 모두 0으로 처리하며, 히스토리 화면 진입 시 요약 정보가 완벽히 연동되도록 계획을 수정 및 보완하였습니다.

## User Review Required

> [!IMPORTANT]
> 1. **인슐린 잔량 자체 감산 완전 배제:**
>    - Flutter 네이티브 앱 및 웹뷰 자바스크립트 내에 인슐린 잔량을 수동으로 직접 계산하여 빼는 로직이 전혀 없음을 재검증합니다.
>    - 가상 BLE 기기 시뮬레이터([mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)) 내에서 주입 요청(`btInjReq`) 수신 시 `_insulinRemain`을 수동으로 감산하던 코드를 완전히 삭제합니다. 이로써 시뮬레이터 환경에서도 실제 기기처럼 기기가 수신한 잔량 데이터 고정값을 온전히 돌려주게 되어 자체 감산에 따른 오동작을 완벽히 방지합니다.
> 2. **이력 값이 없는 월/일 0.0 표시:**
>    - 히스토리 화면([code.html](file:///e:/projects/healus/ui_design/history/code.html))의 `buildSeries` 에서 로컬 DB 로그에 일치하는 날짜 데이터(`match`)가 존재하지 않는 경우, 중심일(`offset === 0`) 여부와 상관없이 모든 주입 값(기초, 식사, 저녁, 추가)을 `0.0`으로 표기하도록 수정합니다.
> 3. **히스토리 상단 요약 정보 네이티브 직접 주입:**
>    - `localStorage` 공유 이슈를 방지하기 위해, 히스토리 화면([code.html](file:///e:/projects/healus/ui_design/history/code.html)) 진입 시 네이티브([main.dart](file:///e:/projects/healus/lib/main.dart))에서 직접 대시보드 누적 값(`basalSum`, `mealSum`, `appendSum`)을 자바스크립트를 통해 `localStorage` 및 화면 요약 엘리먼트에 강제 다이렉트 주입하도록 보완합니다.

## Proposed Changes

### UI & Webview Layer

---

#### [MODIFY] [code.html (history)](file:///e:/projects/healus/ui_design/history/code.html)
- `updateSummaryFromLocalStorage`에서 로드하는 기본값을 기존 '1.5' 등에서 `'0.0'` 또는 `'0'`으로 통일합니다.
- `buildSeries` 내에서 매칭되는 로그가 없을 경우(`else` 블록) 중심일(`offset === 0`) 조건에 따른 하드코딩된 디폴트 값 주입을 제거하고, 모두 `0.0`으로 채워지도록 수정합니다.
- 새로고침 버튼(`refresh-btn`) 클릭 시 비동기 동기화 수집 속도를 고려하여 페이지 새로고침(`window.location.reload()`)을 수행하지 않고, 네이티브 콘솔 전송(`REQUEST_HISTORY_LOGS`)만을 트리거하도록 변경합니다. 네이티브가 수집 완료 후 브릿지 콜백(`window.receiveBleHistoryLogs`)으로 데이터를 반환하면 화면이 자동으로 리렌더링됩니다.

### Native Sync & Parser Layer

---

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- 히스토리 페이지 진입 시(`_currentUrl.contains("history/code.html")`), `_sendHistoryLogsToWebview()` 호출 직후 `basalSum`, `mealSum`, `appendSum` 값을 웹뷰의 `localStorage` 및 `summary-basal`, `summary-meal`, `summary-append` 요약 DOM 요소에 직접 문자열 형태로 다이렉트 삽입 및 주입해주는 스크립트를 추가하여 완벽한 실시간 동기화를 보장합니다.

#### [MODIFY] [mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)
- `case Opcodes.btInjReq:` 블록 내부의 `_insulinRemain = (_insulinRemain - rawVal).clamp(0, 30000);` 감산 시뮬레이션 코드를 완전히 제거합니다. 이를 통해 기기 잔량을 고정 잔량(75.0U)으로 유지하여 송출하게 함으로써 앱 측에서 수신되는 패킷 정보 이외에 어떠한 자체 계산/감산도 관여할 수 없도록 보장합니다.

## Verification Plan

### Automated Tests
```powershell
flutter test test/basal_sync_controller_test.dart
flutter test test/pump_state_provider_test.dart
```

### Manual Verification
1. 에뮬레이터에서 **대시보드** 진입 -> 인슐린 잔량 및 요약 확인.
2. **히스토리** 화면으로 이동 -> 상단 금일 주입 요약이 대시보드 누적 값과 다이렉트로 일치하는지 확인.
3. 히스토리 **새로고침** 클릭 -> 페이지 리로드 현상 없이 네이티브가 수집을 완료한 뒤 그래프와 하단 테이블이 정상적으로 리렌더링되는지 확인.
4. 이력 데이터가 없는 월/일 영역(중심일 포함)이 모두 `0.0`으로 정상 표기되는지 확인.
5. 주입(식사 및 추가) 동작 테스트를 수행한 후, 대시보드의 인슐린 잔량이 주입 실행 시점이나 임의 시점에 자체적으로 줄어들지 않고, 완료 알림(`0x3B` 수신) 및 상태 응답 패킷의 잔량 수신 값으로만 엄격히 갱신되는지 육안 확인.
