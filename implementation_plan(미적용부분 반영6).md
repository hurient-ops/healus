# HealUs 요구사항 구현 계획서

사용자가 요청한 4가지 추가 요구사항을 반영하기 위한 설계 계획입니다.

## User Review Required

> [!IMPORTANT]
> **핵심 변경 사항**
> 1. **히스토리 이력 데이터 DB 보존 기간 180일 확장**: 기존 15일치 제한(`keepOnlyLast15Days`)을 `keepOnlyLast180Days`로 수정하고, 웹뷰에 로드되는 데이터 채우기 범위도 최근 180일치로 늘려 과거 조회가 가능하게 합니다.
> 2. **초기값 0.00화**: 모의 BLE 장치에서 생성되는 히스토리 초기 이력 데이터와 24시간 기초 설정값의 초기값을 모두 `0.00`으로 기본 세팅하여 앱 초기 런칭 시 무설정 상태를 모사합니다.
> 3. **추가주입 화면의 요약 동기화**: `add_injection/code.html` 화면에 진입 시 하드코딩되었던 기초/식사/추가 주입량이 대시보드의 실측 상태와 연동되도록 웹뷰 로컬스토리지 기반 동기화 스크립트를 주입하고 HTML 내부 코드를 보완합니다.

## Proposed Changes

### 1. Database 및 동기화 제어
---

#### [MODIFY] [local_db.dart](file:///e:/projects/healus/lib/services/database/local_db.dart)
- `keepOnlyLast15Days()` 인터페이스 및 Sqflite DB 구현체 메소드명을 `keepOnlyLast180Days()`로 변경합니다.
- 내부 DELETE 쿼리의 `LIMIT 15`를 `LIMIT 180`으로 수정하여 최근 180일치 데이터만 보존하도록 정리합니다.

#### [MODIFY] [basal_sync_controller.dart](file:///e:/projects/healus/lib/services/sync/basal_sync_controller.dart)
- 이력 데이터를 DB에 저장하거나 벌크 인서트 한 직후 호출되는 `_db.keepOnlyLast15Days()` 코드를 `_db.keepOnlyLast180Days()`로 수정합니다.
- `reloadLogsFromDb()` 메소드 내부의 루프 횟수를 `15`에서 `180`으로 변경하여 최근 180일간의 날짜를 생성하고 로그 데이터가 누락된 날짜는 0으로 채워 웹뷰에 전달하도록 처리합니다.

### 2. 가상 BLE 모의 데이터 및 상태 제어
---

#### [MODIFY] [mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)
- 24시간 기초 설정 초기값 배열인 `_basalRates`을 전부 `0.00`으로 초기화하며, 생성자 내부의 `1.20` 기본값 할당 루프를 제거합니다.
- 누적 주입량 모의 변수들(`_basalSum`, `_morningSum`, `_lunchSum`, `_eveningSum`, `_appendSum`)의 초기값을 모두 `0.00`으로 지정합니다.
- `btLogReq` 수신 시뮬레이션 처리 시, 이력 루프 횟수를 `180`회(`for (int i = 179; i >= 0; i--)`)로 늘리고, 패킷 바이트 내부의 수치들을 모두 `0.00`으로 변경하여 전달합니다.

### 3. 추가주입 UI 및 웹뷰 연동 설정
---

#### [MODIFY] [code.html (add_injection)](file:///e:/projects/healus/ui_design/add_injection/code.html)
- 내부 JS 스크립트 중 하드코딩된 `bleState` (basal 12.50, meal 8.25, add 2.00) 부분을 `localStorage`에서 동적으로 값을 읽어와 바인딩하도록 수정합니다.
  - `localStorage`에 값이 없거나 `'---'` 상태일 때만 `0.00`으로 대체되도록 안전하게 연동합니다.

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- `_currentUrl.contains("add_injection/code.html")`인 경우의 분기 조건을 추가하여, 해당 웹뷰 화면이 로드되었을 때 `basalSum`, `mealSum`, `appendSum` 등의 `localStorage` 데이터가 제대로 설정되고 UI 요소(`val-basal`, `val-meal`, `val-add`) 텍스트가 실측값으로 채워지도록 스크립트 실행 처리를 추가합니다.

## Verification Plan

### Manual Verification
1. **앱 초기 구동**: 
   - 앱이 재실행되었을 때, 기초설정 화면 및 대시보드 초기값이 `0.00`으로 정상적으로 표시되는지 확인합니다.
2. **히스토리 이력 전송**:
   - 가상 BLE 동기화 이후 히스토리 화면에서 이력 데이터가 전부 `0.00`으로 초기화되어 180일치로 나타나는지 확인하고, 날짜 캘린더 조작을 통해 최근 180일까지의 날짜 범위가 적절하게 반영되는지 점검합니다.
3. **추가 주입 화면 요약 동기화**:
   - 대시보드 메인에서 추가 주입 화면으로 이동하여 상단의 "현재 요약" 수치가 대시보드 메인 화면의 기초주입, 식사주입, 추가주입 수치와 완벽하게 일치하는지 확인합니다.
