# Dashboard Smart Refresh for Dropped BLE Packets

대시보드 최초 진입 시 펌프로부터 가져와야 할 8개의 필수 데이터(배터리, PID, 금일 주입량, 식사설정, 기초설정, 주입정보, FW버전, 이력데이터)를 체계적으로 관리하고, 누락(Drop) 발생 시 새로고침 버튼을 눌렀을 때 똑똑하게 **빠진 패킷만 핀포인트로 재요청**하는 로직을 구현합니다.

## User Review Required

- 새로고침 시 누락된 패킷이 하나라도 있으면 **빠진 패킷들만 재요청**하며, 이때 화면 새로고침(Reload)은 발생하지 않습니다.
- 누락된 패킷이 하나도 없다면(모두 수신 완료 상태) 새로고침 버튼 클릭 시 **단순히 화면(웹뷰)만 갱신(Reload)**합니다.
- 제안드린 로직 흐름이 원하시는 동작과 100% 일치하는지 확인해 주시면 바로 코딩을 시작합니다.

## Proposed Changes

---

### main.dart (Flutter BLE 상태 제어)

#### [MODIFY] main.dart
1. **대기 명단(Set) 상태 변수 추가**
   - `Set<int> _pendingInitialRequests = {};` 변수를 선언하여 미수신 패킷 리스트를 관리합니다.
2. **최초 동기화 시 리스트 채우기**
   - `_requestDashboardInitialData()`가 호출될 때 `_pendingInitialRequests`에 8개 요청 Opcode(`0x70, 0x09, 0x1E, 0x2D, 0x2F, 0x15, 0x3E, 0x1D`)를 모두 담아둡니다.
3. **수신 완료 시 리스트에서 제거**
   - `_subscribeToBleService()` 내부에서 패킷이 수신될 때마다 응답 Opcode를 분석하여 원래 요청 Opcode를 짝지어 `_pendingInitialRequests.remove()`로 삭제합니다.
4. **스마트 새로고침(Refresh) 처리 로직 추가**
   - 웹(HTML)에서 `REQUEST_DASHBOARD_REFRESH` 콘솔 메시지가 날아올 경우:
     - `_pendingInitialRequests`가 **비어있다면**: `_controller.reload()`를 호출하여 화면만 다시 로딩.
     - `_pendingInitialRequests`가 **남아있다면**: 남은 Opcode들만 추출하여 각각의 전송 규칙(예: `0x15`는 파라미터 `[2]=1, [3]=0` 추가 등)에 맞게 패킷을 생성해 펌프에 재요청.

---

### dashboard/code.html (웹 프론트엔드 제어)

#### [MODIFY] dashboard/code.html
- **새로고침 버튼 이벤트 수정**
  - 기존에는 단순히 새로고침 아이콘만 뱅글뱅글(spin) 돌고 끝났으나, 이벤트 안에 `console.log("REQUEST_DASHBOARD_REFRESH");` 코드를 추가하여 Flutter 앱으로 새로고침 신호를 전달하도록 수정합니다.

## Verification Plan

### Manual Verification
1. 앱 재실행 후 최초 대시보드 진입 시 전체 데이터를 한 번에 요청하는지 확인.
2. 가상의 환경(혹은 실제 펌프)에서 고의로 특정 패킷(예: 식사설정 `0x2E`) 응답을 주지 않은 상태로 대기.
3. 우측 상단 리프레시 아이콘 클릭 시, 8개를 다 요청하지 않고 오직 누락되었던 `0x2D`(식사설정) 패킷만 다시 요청하는지 플러터 로그를 통해 확인.
4. 다시 식사설정 응답(`0x2E`)을 보내 미수신 리스트를 비운 뒤, 새로고침을 누르면 웹뷰 화면이 깜빡이며 정상 리로딩되는지 확인.
