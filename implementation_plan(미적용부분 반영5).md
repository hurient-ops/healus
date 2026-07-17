# 대시보드 리프레시 시 상태 롤백 및 히스토리 정렬 오류 해결을 위한 구현 계획 (최종본)

이 계획은 대시보드 화면 및 히스토리 화면에서 새로고침(리프레시)을 누르거나 다른 화면으로 이동했다 돌아왔을 때, 오늘의 요약, 배터리 잔량, 인슐린 잔량, 식사 설정값, 그리고 히스토리 이력 로그 데이터가 이전 값(하드코딩된 가상 초기값)으로 되돌아가는 현상을 방지하고, 히스토리 Y축 눈금 어긋남을 근본적으로 해결하기 위한 최종 설계서입니다.

## User Review Required

> [!IMPORTANT]
> **1. 실제 패킷 수신 시 가상 하드코딩 응답 무시 및 실측 데이터 보존 정책 (전 영역 확대)**
> - 사용자가 디버그 패널을 통해 가상 패킷을 수동 주입하거나 실제 BLE 장치로부터 수신된 패킷이 한 번이라도 유입되면, 이 값은 **실제 실측 패킷 데이터**로 판별됩니다.
> - 실측 패킷 데이터가 유입되면 `PumpStateData` 및 `BasalSyncState`에 `hasReceivedRealSummary`, `hasReceivedRealBattery`, `hasReceivedRealInsulin`, `hasReceivedRealMeal`, `hasReceivedRealLogs` 플래그를 `true`로 설정합니다.
> - 이후 새로고침 등으로 대시보드 및 히스토리 재진입 시 `_requestDashboardInitialData()`가 실행되어 `MockBleService`가 디폴트 가상 패킷들을 던지더라도, 기존의 실측 플래그가 `true`이므로 **가짜 디폴트 데이터는 무시**하고 기존에 수신된 패킷 데이터의 최종 상태(로컬 DB 및 메모리 상태)를 계속 보존 및 유지합니다.
> - 이로써 앱이 완전히 종료되고 재실행되기 전까지는 수신된 실제 패킷을 기준으로 데이터가 지속적으로 유지되고 업데이트됩니다.
>
> **2. 히스토리 Y축 눈금 및 수평선 일치화**
> - `ui_design/history/code.html`에서 Y축 눈금 레이블(100, 80, 60 등)의 컨테이너 상단에 날짜 표시 영역(`chart-date-row`)의 높이(`15px` + margin-bottom `4px`)와 완벽하게 대칭을 이루는 spacer인 `<div class="h-[15px] mb-1"></div>`을 추가합니다.
> - 이로써 눈금의 100, 80, 60, 40, 20, 0 텍스트들의 중심 y좌표가 그래프 영역 내부의 수평 그리드선과 완전히 1:1 매칭 정렬되도록 정밀 조정합니다.

## Proposed Changes

---

### [BLE Service & Bridging Layer]

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- **BLE 수신 리스너의 실측 패킷 판별**:
  - `_subscribeToBleService` 내에서 `receivedPacketsStream`으로부터 유입되는 패킷을 인계할 때, `!bleService.isTestMode` (실제 하드웨어 통신 중)인 경우 `isRealPacket: true` 플래그를 넘겨줍니다.
  - `_showDebugPacketDialog` 내에서 사용자가 직접 수동 주입을 실행할 때, 펌프 상태와 동기화 컨트롤러에 모두 `isRealPacket: true` 아규먼트를 설정해 명시적으로 실측 패킷으로 처리하게 보장합니다.
    ```dart
    ref.read(pumpStateProvider.notifier).handleIncomingPacket(bytes, isRealPacket: true);
    ref.read(basalSyncControllerProvider.notifier).handleIncomingPacket(bytes, isRealPacket: true);
    ```

---

### [State & Logic Layer]

#### [MODIFY] [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
- **실측 패킷 상태 관리 변수 추가**:
  - `PumpStateData`에 `hasReceivedRealSummary`, `hasReceivedRealBattery`, `hasReceivedRealInsulin`, `hasReceivedRealMeal` 멤버 변수를 추가합니다. (기본값 `false`)
- **디폴트 가상 패킷 무시 로직 구현**:
  - `handleIncomingPacket` 메서드에 `bool isRealPacket` 아규먼트를 추가합니다.
  - 배터리(`btBattDataInd`), 누적 주입량(`btLogInjQntInd`), 인슐린 잔량(`btInjInfoRes`, `btSetRes`, `btInjStopInd`), 식사설정 값(`btEatValueRes`, `btLogInjSet1Ind`) 처리 부분에서 `isRealPacket`이 `false`이고 실측 플래그가 `true`이면 업데이트를 무시하도록 처리합니다.

#### [MODIFY] [basal_sync_controller.dart](file:///e:/projects/healus/lib/services/sync/basal_sync_controller.dart)
- **로그 실측 데이터 관리 변수 추가**:
  - `BasalSyncState`에 `hasReceivedRealLogs` 멤버 변수를 추가합니다. (기본값 `false`)
- **디폴트 가상 로그 패킷 무시 로직 구현**:
  - `handleIncomingPacket` 메서드에 `bool isRealPacket` 아규먼트를 추가합니다.
  - 이력 대량 전송 시작 패킷(`btDataStartInd`) 수신 시 `isRealPacket`이 `true`이면 `hasReceivedRealLogs = true`로 설정합니다.
  - 만약 `isRealPacket`이 `false`인데 `hasReceivedRealLogs`가 `true`인 경우, `btDataStartInd` 수신을 완전히 무시(`break`)하여 이후에 쏟아지는 모의 15일치 데이터가 DB에 침투하거나 유입되지 않도록 차단합니다.

---

### [UI Design (HTML/CSS)]

#### [MODIFY] [history/code.html](file:///e:/projects/healus/ui_design/history/code.html)
- **Y축 눈금 레이아웃 정밀 수정**:
  - Y축 텍스트 레이블 컨테이너 상단에 spacer 엘리먼트를 삽입하여 차트 내용과의 수평 정렬을 정밀 조율합니다.
  ```html
  <div class="w-8 shrink-0 flex flex-col">
    <!-- chart-date-row 및 margin-bottom(mb-1)과 대칭되는 spacer 높이 15px 확보 -->
    <div class="h-[15px] mb-1"></div> 
    <!-- Y-axis values with vertical alignment matched to border grid -->
    <div class="w-full shrink-0 pr-1 text-[10px] text-gray-400 text-right h-[320px] relative">
      <span class="absolute right-1" style="top: 0%; transform: translateY(-50%);">100</span>
      ...
    </div>
  </div>
  ```

---

## Verification Plan

### Automated Tests
- `flutter test`를 실행하여 기존 상태 검증 테스트 코드가 정상 동작하는지 검토합니다.

### Manual Verification
1. **가상 패킷 수동 주입 테스트**:
   - 디버그 패널을 열어 인슐린 잔량 150.0 U 또는 배터리 75%, 식사 설정 값(아침 2.5U 등), 이력 데이터 수집 패킷 등을 수동 주입합니다.
   - 대시보드 및 히스토리 요약/차트 값이 수동 주입된 패킷에 맞춰 즉각 갱신되는지 확인합니다.
2. **새로고침(Refresh) 롤백 방지 검증**:
   - 새로고침(Refresh) 버튼을 눌러 웹뷰를 리로드합니다.
   - 웹뷰가 새로 로딩되며 `_requestDashboardInitialData()`가 실행되어 가상 기기가 디폴트 응답(배터리 50%, 인슐린 300U 등)을 던지더라도, 펌프 상태 및 동기화 컨트롤러가 이를 무시하고 수동 주입된 실측 값을 롤백 없이 안전하게 보존하는지 검증합니다.
3. **히스토리 Y축 정렬 검증**:
   - 에뮬레이터 화면을 확인하여 Y축 눈금(100, 80, 60, 40, 20, 0)의 중앙선이 차트 영역 내부의 수평 그리드선과 픽셀 단위로 정확히 일치하는지 확인합니다.
