# Healus 인슐린 펌프 연동 추가 개발 및 오류 수정 계획

이 문서는 대시보드 상태 롤백, 주기적 데이터 요청, 이력 데이터 처리(DB 15일 보존 및 월/일 복합 키 중복 방지), Y축 텍스트 정렬, 비밀번호 암호인증 갱신 문제를 근본적으로 해결하기 위한 구체적인 구현 계획입니다.

## User Review Required

> [!IMPORTANT]
> - **대시보드 패킷 미수신 대응**: 블루투스 실제 연동 모드에서 기기로부터 최초 패킷(배터리, 인슐린 잔량, 요약 데이터)을 수신하기 전까지는 대시보드 화면에 디폴트 값(300U, 배터리 100% 등)을 띄우지 않고 `---`로 노출함으로써 초기값 롤백 현상을 완전히 예방합니다. 단, 테스트 모드일 때는 기존처럼 모의 데이터가 즉시 나타납니다.
> - **히스토리 이력 및 그래프 표시**: 
>   - DB는 `month`와 `day`를 복합 키(Unique Key)로 설정하여 동일 날짜의 이력이 중복으로 쌓이지 않고 항상 덮어써져 저장됩니다. DB 용량은 최대 15일치만 보존됩니다.
>   - 히스토리 화면 그래프에는 오늘과 이전 4일치(최종 5일치)만 필터링하여 보여줍니다. DB에 데이터가 없는 날짜는 모든 주입량이 `0.0`으로 자동 대치되어 렌더링됩니다.
> - **초기 비밀번호 차단**: 기기 패킷(`0x3D`, `0x42`)을 수신하여 비밀번호가 설정된 상태에서는 이전 초기 암호인 `"000000"`을 입력하더라도 인증이 거부되도록 차단됩니다.

## Open Questions

- 없음. 사용자 요구사항에 기초하여 모든 시나리오가 구체적으로 설계되었습니다.

## Proposed Changes

---

### [State & Provider]

#### [MODIFY] [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
- `PumpStateData` 모델에 패킷 수신 기록을 식별하기 위한 플래그 추가:
  - `bool hasReceivedBattery` (기본값: `false`)
  - `bool hasReceivedInsulin` (기본값: `false`)
  - `bool hasReceivedSummary` (기본값: `false`)
  - `bool isPasswordProvisioned` (기본값: `false`)
- `PumpStateNotifier` 내 `handleIncomingPacket()` 리스너에서 패킷 수신 시 플래그 갱신:
  - `btBattDataInd (0x71)`, `btBattDataRes (0x72)`: `hasReceivedBattery = true`
  - `btSetRes (0x12)`, `btInjInfoRes (0x16)` 등 인슐린 잔량 갱신 시: `hasReceivedInsulin = true`
  - `btLogInjQntInd (0x1F)`: `hasReceivedSummary = true`
  - `btPrsAppPasswdRes (0x3D)`, `btNewAppPasswdInd (0x42)`: `password`를 업데이트하고 `isPasswordProvisioned = true` 설정

---

### [Poller & Sync Controller]

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- **주기적 금일 주입량 폴링**:
  - `_qntTimer` 및 `_qntInterval` (기본 `Duration(minutes: 30)`) 변수 추가.
  - 블루투스 연결이 감지되면 `_startQntPollTimer()` 호출, 연결 유실 시 `_stopQntPollTimer()` 호출.
  - 타이머 작동 시 30분 주기로 `BT_LOG_INJ_QNT_REQ (0x1E)` 패킷 요청 전송.
- **이력 패킷 1회성 요청 제한**:
  - `_hasRequestedHistoryLogs` 플래그를 두어, 로그인 후 대시보드 최초 진입 시 (`_requestDashboardInitialData` 내에서) `BT_LOG_REQ (0x1D)`를 딱 1회만 호출하도록 제한.
  - 히스토리 화면 진입 시점에 `requestHistoryLogs()` 호출부를 제거하고 DB에서 로그 데이터를 읽어들이는 `reloadLogsFromDb()`만 실행하도록 수정.
- **초기값 롤백 및 패킷 미수신 시 방어 처리**:
  - `_syncStateToWebview` 메서드에서 `testMode`가 `false`이고 각 정보가 수신되지 않은 경우(각 플래그가 `false`인 경우) 웹뷰에 실데이터 대신 `---` 텍스트를 전송하고 로컬스토리지에도 `'---'`를 주입하도록 처리.
- **비밀번호 갱신 및 초기 비밀번호 `"000000"` 접근 차단**:
  - `_loadInterceptedPasswordPage()`에서 `pumpState.isPasswordProvisioned`가 `true`일 때는 기기에서 수신된 실비밀번호를 바인딩하고, `false`일 때는 기본 `"000000"`을 매핑.
  - `pumpStateProvider` 리스너에서 `password`나 `isPasswordProvisioned`가 갱신되고 현재 화면이 `password/code.html` 관련 URL인 경우, 즉시 `_loadInterceptedPasswordPage()`를 재호출하여 변경 사항을 웹뷰 화면에 실시간으로 다시 반영.

#### [MODIFY] [basal_sync_controller.dart](file:///e:/projects/healus/lib/services/sync/basal_sync_controller.dart)
- `btLogInjQntInd (0x1F)` 패킷 수신 시:
  - 현재 시스템 날짜(Month, Day)를 획득하여 오늘의 기초, 식사, 추가 주입량 합산본을 `PumpLogModel` 레코드로 생성.
  - `SqflitePumpDatabase`에 `insertLog`를 통해 오늘 날짜 데이터를 강제 덮어쓰기하여 저장 (Unique 복합 키 구조로 자동 덮어쓰기됨).
  - 이후 `keepOnlyLast15Days()` 호출하여 DB의 고유 날짜 크기를 15일치로 보존.
  - `reloadLogsFromDb()`를 트리거하여 변경된 데이터셋을 웹뷰로 실시간 푸시.
- `reloadLogsFromDb()` 로직 변경:
  - DB에서 로드된 로그 목록(`allLogs`)에 기반해, 오늘 날짜를 기준으로 과거 15일간의 날짜를 계산.
  - 각 날짜에 해당하는 DB 로그가 있는 경우 그대로 사용하고, 데이터가 없는 날짜는 모든 주입량이 `0.0`인 레코드를 가상 생성하여 15일 분량의 순차적 리스트를 완성.
  - 이 정제된 15일 분량의 이력 리스트를 `state.logs`에 저장하여 웹뷰에 최종 송출.

---

### [Database]

#### [MODIFY] [local_db.dart](file:///e:/projects/healus/lib/services/database/local_db.dart)
- `PumpDatabase` 인터페이스 및 `SqflitePumpDatabase` 클래스에 `keepOnlyLast15Days()` 메서드 스펙 및 구현 추가.
- `SqflitePumpDatabase`의 `onCreate`에서 `UNIQUE(month, day) ON CONFLICT REPLACE` 제약 조건을 추가하여 동일 날짜의 이력이 중복으로 쌓이지 않고 `insert` 시 덮어쓰기가 보장되도록 수정.
- `keepOnlyLast15Days()`: SQLite DB에서 고유 날짜(Month, Day)를 기준으로 내림차순 정렬하여 최신 15일 분량의 날짜 데이터만 남기고, 이전 데이터를 일괄 정리하는 삭제 쿼리 실행.
  ```sql
  DELETE FROM pump_logs 
  WHERE id NOT IN (
    SELECT id FROM pump_logs 
    WHERE (month * 100 + day) IN (
      SELECT (month * 100 + day) as date_val 
      FROM pump_logs 
      GROUP BY date_val 
      ORDER BY date_val DESC 
      LIMIT 15
    )
  )
  ```

---

### [UI Design (HTML/CSS)]

#### [MODIFY] [dashboard/code.html](file:///e:/projects/healus/ui_design/dashboard/code.html)
- `DOMContentLoaded` 시점의 초기 상태 데이터 바인딩 로직 수정:
  - 로컬스토리지에서 읽어들인 배터리 잔량이나 인슐린 잔량이 `'---'` 혹은 `null`인 경우, `---` 텍스트를 노출하고 프로그레스 바의 너비를 `0%`로 처리하여 렌더링 에러를 예방.
  - 기초, 식사, 추가 주입의 초기 상태값도 로컬스토리지에 값이 없을 경우 `'---'`가 디폴트로 표시되도록 수정.

#### [MODIFY] [history/code.html](file:///e:/projects/healus/ui_design/history/code.html)
- **금일 주입 내용 디폴트 수정**:
  - `updateSummaryFromLocalStorage()`에서 로컬스토리지에 값이 없을 시 `'0.0'` 대신 `'---'`로 출력되도록 수정.
- **Y축 눈금선 정렬 위치 수정**:
  - Y축의 100, 80, 60, 40, 20 수치 텍스트 `span`들의 CSS `transform: translateY(-50%);` 속성을 `translateY(-30%);`로 미세 하향 정렬하여 그리드 수평선의 정중앙에 올바르게 배치.
  - 0 텍스트의 CSS `transform: translateY(50%);` 속성도 `translateY(30%);`로 함께 수정하여 보정.

## Verification Plan

### Automated Tests
- DB의 15일 관리 및 누락된 날짜 0 채움 로직에 대한 로직 단위 테스트 수행.
- 에뮬레이터 환경에서 디버그 애플리케이션 구동 및 핫 리스타트 확인.

### Manual Verification
- **대시보드 리로드 및 화면 이동 테스트**: 화면 전환 및 핫 리스타트 시 대시보드의 값이 초기값(300U 등)으로 복원되지 않고 `---` 상태로 유지되며, 기기 데이터 패킷 유입 시 실시간으로 바인딩되는지 확인.
- **주기적 금일 주입량 전송**: 로그 캡처를 통해 30분(또는 테스트용 시간 조절) 주기로 `0x1E` 패킷이 큐에 쌓여 송출되는지 확인.
- **히스토리 데이터 및 Y축 정렬**: 날짜를 변경하거나 다른 화면에 이동했다 복귀해도 차트 데이터가 그대로 유지되며, Y축 텍스트 눈금이 수평 그리드선과 시각적으로 깔끔하게 수평 일치하는지 확인.
- **비밀번호 갱신 검증**: 기기로부터 신규 비밀번호 변경 패킷이 도착한 뒤, 기본 비밀번호인 `"000000"`으로는 인증이 불발되고 변경된 새 암호로만 통과되는지 확인.
