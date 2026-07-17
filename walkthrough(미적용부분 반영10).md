# HealUs 요구사항 구현 검증 결과

요청하신 네 가지 요구사항에 대해 모든 수정을 진행하였으며, 정상적으로 작동함을 검증 완료하였습니다.

## 구현 및 변경 세부 내용

### 1. 히스토리 이력데이터 DB 용량 180일 확장
- **[local_db.dart](file:///e:/projects/healus/lib/services/database/local_db.dart)**: 기존 15일치 보존 제한이었던 `keepOnlyLast15Days()`를 `keepOnlyLast180Days()`로 명칭 및 로직을 변경하였습니다. DELETE SQL 쿼리의 `LIMIT` 범위를 `180`으로 수정하여 최근 180일 데이터만 안전하게 보존하도록 확장했습니다.
- **[basal_sync_controller.dart](file:///e:/projects/healus/lib/services/sync/basal_sync_controller.dart)**: 로그 벌크 인서트 및 싱글 인서트 완료 후 `keepOnlyLast180Days()`를 호출하게 수정하였으며, 웹뷰에 로딩하는 데이터 범위를 최근 180일치로 확장하기 위해 `reloadLogsFromDb()` 메소드 내의 날짜 루프 범위를 180일(`for (int i = 179; i >= 0; i--)`)로 대폭 늘렸습니다.

### 2. 히스토리 DB 및 모의 로그 초기값 0.00화
- **[mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)**: BLE 패킷 요청(`btLogReq`)을 처리할 때 기존에 들어가던 기초(0.80), 식사(3.00), 아침(1.00) 등의 기본 모의 이력 데이터를 모두 `0.00` 단위수로 변경하였으며, 일수 또한 180일치 로그를 송신하게 변경해 DB가 0.00의 초기 데이터로 180일간 적재됨을 보장했습니다.

### 3. 기초설정 초기값 0.00 변경
- **[mock_ble_service.dart](file:///e:/projects/healus/lib/services/ble/mock_ble_service.dart)**: 24구간 기초 주입량 속도를 모사하는 `_basalRates` 배열의 초기값을 `0.80`에서 `0.00`으로 변경하고, 생성자 내부에서 주간 주입량을 `1.20`으로 덮어씌우던 루프를 제거하였습니다. 또한 금일 주입량 모의 변수들(`_basalSum`, `_morningSum`, `_lunchSum`, `_eveningSum`, `_appendSum`)을 모두 `0.00`으로 초기화하여 무설정 상태를 완전하게 재현했습니다.

### 4. 추가주입 현재 요약 화면 동기화
- **[code.html (add_injection)](file:///e:/projects/healus/ui_design/add_injection/code.html)**: 화면 로드 시 하드코딩되었던 기초(12.50 U), 식사(8.25 U), 추가(2.00 U) 요약 정보를 제거하고, `localStorage`로부터 실측 누적 주입량을 읽어와 동적으로 바인딩하도록 스크립트를 개선했습니다.
- **[main.dart](file:///e:/projects/healus/lib/main.dart)**: 추가 주입 웹뷰 화면이 열릴 때도 대시보드와 동일한 주입 수치 텍스트(`basalText`, `mealText`, `appendText`)를 `localStorage`에 동기화하고 웹뷰 DOM 요소(`val-basal`, `val-meal`, `val-add`)에 직접 렌더링되게 하는 스크립트 주입 분기 처리를 추가하였습니다.

---

## 검증 결과 사진

### 추가주입 화면 현재 요약 동기화 완료
대시보드의 실측값(기초 0.0 U, 식사 0.0 U, 추가 0.0 U)이 추가주입 화면 상단의 "현재 요약" 영역에 실시간 연동되어 하드코딩 값 없이 `0.00 U`로 정확하게 출력되는 것을 확인할 수 있습니다.

![추가주입 요약 동기화 검증](/C:/Users/COMPANY/.gemini/antigravity-ide/brain/7354fb07-dfc9-45cc-bb93-76b14ca4149d/healus_add_injection_sync.png)
