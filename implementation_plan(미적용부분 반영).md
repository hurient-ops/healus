# 인슐린 펌프 기능 고도화 및 7가지 요구사항 추가 개발 구현 계획서

이 계획서는 HealUs 모바일 앱과 인슐린 펌프 간의 추가적인 동기화 기능 및 설정 제어 명령 연동을 위한 구체적인 구현 방안을 다룹니다.

---

## 1. User Review Required (사용자 검토 필요 사항)

> [!IMPORTANT]
> **대시보드 진입 시 초기 데이터 일괄 요청 및 동기화**
> - 비밀번호 인증 완료 후 대시보드(`dashboard/code.html`) 화면에 처음 진입할 때 기기로부터 5가지 주요 초기 상태를 자동으로 순차 요청하도록 네이티브 초기화 로직을 정비합니다.
> - 주기적인 배터리 잔량 요청(`BT_BATT_DATA_REQ`, 0x70)은 기본 30분 주기로 동작하며, 이 주기는 `main.dart` 상단에 `Duration _batteryInterval = const Duration(minutes: 30);` 변수로 노출하여 추후 수정을 용이하게 조치합니다.

> [!WARNING]
> **기초설정 동기화 시 Ack 대기 락 해제**
> - 6회 분할 송신 과정에서 `BT_SET_RES` (0x12) 응답 수신 시에도 Ack 대기 비동기 잠금(`_basalAckCompleter`)을 올바르게 해제하여, 5초 타임아웃 락 현상을 원천 방지합니다.

---

## 2. Proposed Changes (제안된 변경 사항)

### A. 기초설정 저장 시의 Ack 락 해결
- **파일**: [main.dart](file:///e:/projects/healus/lib/main.dart)
  - `_subscribeToBleService` 내에서 수신된 패킷의 opcode가 `Opcodes.btSetRes` (0x12) 인 경우에도 `basalSyncControllerProvider`에 설정 완료 신호를 포워딩합니다.
  ```dart
  if (packet[1] == Opcodes.btMsgRes) {
    final targetOp = packet[3];
    final resCode = ResCode.fromValue(packet[4]);
    if (targetOp == Opcodes.btTimeBaseSetReq || targetOp == Opcodes.btMealSetReq) {
      ref.read(basalSyncControllerProvider.notifier).handleSetResponse(resCode);
    }
  } else if (packet[1] == Opcodes.btSetRes) {
    // btSetRes 수신 시에도 Ack 대기 해제
    ref.read(basalSyncControllerProvider.notifier).handleSetResponse(ResCode.ok);
  }
  ```

### B. 설정 화면 내 일시 정지/장치 재개/연결 해제/초기화 브릿지 연동
- **파일**: [main.dart](file:///e:/projects/healus/lib/main.dart)
  - `_handleConsoleMessage()` 에 웹뷰가 방출하는 콘솔 명령어 대응 로직을 추가합니다.
    - **`PAUSE` 감지 시**: `BT_STOP_CTRL_REQ (0x0D)` 메시지에 `1` (일시정지 설정) 페이로드를 담아 송신.
    - **`RESUME` 감지 시**: `BT_STOP_CTRL_REQ (0x0D)` 메시지에 `0` (일시정지 해제) 페이로드를 담아 송신.
    - **`DISCONNECT` 감지 시**: 실제 BLE 연결을 끊기 위해 `ref.read(bleServiceProvider).disconnect()`를 수행하고 `testModeProvider`를 비활성화(`false`)한 후, 연결 대기 페이지(`ble_connect/code.html`)로 이동.
    - **`RESET` 감지 시**: `BT_SYSTEM_RESET (0x43)` 메시지를 송신.

### C. 식사 설정 실시간 양방향 동기화 및 전역 공유
- **파일**: [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
  - 사용자가 입력한 식사 설정값을 공통 장소에 수동 업데이트할 수 있도록 `updateMealSettings(double breakfast, double lunch, double dinner)` 메소드를 추가합니다.
- **파일**: [main.dart](file:///e:/projects/healus/lib/main.dart)
  - 사용자가 식사 설정화면에서 "저장" 버튼을 누를 때 발생하는 콘솔 로그 `"BLE 명령 전송: BT_MEAL_SET_REQ (0x10)"`를 파싱하여 네이티브의 `pumpStateProvider` 공통 상태에 즉시 반영합니다.
  - `_syncStateToWebview()` 메소드에서 `meal_setting/code.html`, `meal_injection/code.html`, `dining/code.html` 화면들이 로드될 때마다 공통 장소에 보존된 아침/점심/저녁 설정값을 로컬스토리지(`meal_settings`)에 자동 주입하고 UI 필드에 갱신하는 코드를 보강합니다.

### D. 배터리 응답(0x72) 수신 및 5단계 프로그레스 바 연동
- **파일**: [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
  - `handleIncomingPacket` 내에 `Opcodes.btBattDataRes` (0x72) 가 수신되었을 때도 `batteryLevel`을 업데이트하도록 케이스를 확장합니다.
- **파일**: [main.dart](file:///e:/projects/healus/lib/main.dart)
  - 대시보드의 `val-battery-pct`와 `bar-battery` 프로그레스 바 너비를 `batteryLevel * 25` % 로 정확히 동기화합니다 (0~4 레벨 -> 0%, 25%, 50%, 75%, 100% 5단계 매핑).

### E. 암호인증 완료 후 대시보드 최초 진입 시 일괄 연쇄 요청
- **파일**: [main.dart](file:///e:/projects/healus/lib/main.dart)
  - 대시보드 화면 최초 진입 시점인 `_requestDashboardInitialData()` 내에 다음 시퀀스를 구성해 요청 패킷들을 큐에 순차 적재합니다:
    1. 배터리 잔량 요청 (`BT_BATT_DATA_REQ`, 0x70) - 30분 주기 타이머 연계
    2. 고유 PID 요청 (`BT_PUMP_PID_REQ`, 0x09)
    3. 금일 주입량 정보 요청 (`BT_LOG_INJ_QNT_REQ`, 0x1E) - 오늘의 요약 바인딩 (기초 -> 기초, 아침+점심+저녁 -> 식사, 추가 -> 추가)
    4. 식사 설정값 요청 (`BT_EAT_VALUE_REQ`, 0x2D)
    5. 24개 시간 구간 기초 설정값 요청 (`BT_BASE_VALUE_REQ`, 0x2F) - 3회 분할 응답 대기

---

## 3. Verification Plan (검증 계획)

### Automated Tests
- `test/pump_state_provider_test.dart`를 실행하여 기존 패킷 파싱 로직 및 신규 식사 설정 수동 업데이트 로직의 정상 동작을 확인합니다.
  - 명령어: `flutter test`

### Manual Verification
1. **기초설정 저장 락 방지**:
   - 기초 설정 페이지에서 저장 버튼 클릭 후 패킷 6회가 지연 없이 연속 전송 완료되는지 확인합니다.
2. **설정 일시정지 및 재개**:
   - 설정 화면에서 '일시 정지' / '장치 재개' 터치 시 `BT_STOP_CTRL_REQ` 패킷이 각각 `1`/`0` 페이로드를 품고 송출되는지 모니터링합니다.
3. **설정 장치 연결 해제 및 초기화**:
   - '장치 연결 해제' 터치 시 BLE 세션 해제 및 연결 대기 화면으로 이탈하는지 확인합니다.
   - '장치 초기화' 터치 시 `0x43` 리셋 패킷이 올바르게 나가는지 검증합니다.
4. **식사설정 양방향 동기화**:
   - 식사설정을 바꾼 후 다른 화면으로 이동했다가 복귀해도 변경한 값이 정확히 보존 및 표출되는지 테스트합니다.
   - 식사주입 및 회식적용 페이지 로드 시에도 이 동일한 식사설정값이 계승되는지 확인합니다.
5. **대시보드 초기화 데이터 동기화**:
   - 로그인 직후 5가지 기기 정보 요청이 한꺼번에 순차 송신되는지 확인하고, 응답 패킷 주입 시 화면 정보(배터리 5단계, 오늘의 요약 등)가 연계 갱신되는지 확인합니다.
