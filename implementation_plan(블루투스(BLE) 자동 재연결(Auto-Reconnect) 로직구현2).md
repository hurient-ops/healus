# [Goal Description]
앞서 적용한 BLE 자동 재연결 및 백그라운드 로직 테스트 과정에서 발견된 3가지 치명적 버그(이탈 시 UI 멈춤, 뒤로가기 종료 후 먹통, 장치 해제 후 재연결 불가)를 근본적으로 해결하기 위한 수정 계획입니다.

## User Review Required
> [!IMPORTANT]
> **앱 종료 방식의 변경 (필수)**
> 현재 대시보드에서 뒤로가기를 2번 누를 때 안드로이드 시스템의 앱 프로세스를 강제 종료하는 `SystemNavigator.pop()`이 사용되고 있습니다. 이 방식은 포그라운드 서비스(백그라운드 통신)를 강제로 고아(Orphan) 상태로 만들어 다음 번 앱 실행 시 화면이 먹통이 되는(엔진 미부착) 원인이 됩니다.
> 이를 `FlutterForegroundTask.minimizeApp()`으로 대체하여, **"종료가 아닌 홈 화면으로 내리기(최소화)"**로 동작하도록 수정합니다. 백그라운드 서비스가 있는 앱의 표준 동작입니다.

## Proposed Changes

### 1. 연결 단절 후 주입 중 상태(UI) 무한 대기 버그 수정
* 펌프와 멀어져 연결이 끊어졌을 때, 큐(Queue)는 비워졌지만 화면에는 여전히 "주입 중"이 떠 있는 문제를 해결합니다.

#### [MODIFY] [pump_state_provider.dart](file:///e:/projects/healus/lib/state/pump_state_provider.dart)
- 연결 끊김 시 화면 상태를 강제로 대기 상태로 돌리는 `resetInjectingState()` 메서드를 추가합니다.

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- `_bleConnectionSub`에서 연결 끊김(`!newState`)을 감지했을 때, 큐를 비울 뿐만 아니라 `resetInjectingState()`를 호출하여 UI Lock을 해제합니다.

---

### 2. "뒤로가기 2번" 종료 후 앱 재실행 불가 현상 수정
* 안드로이드 12+ 환경에서 백그라운드 서비스 구동 중 액티비티 강제 종료 시 발생하는 고질적인 Flutter 엔진 재부착 실패 이슈를 우회합니다.

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- 라우팅 핸들러의 `SystemNavigator.pop()` 호출 부분을 모두 `FlutterForegroundTask.minimizeApp()`으로 교체하여, 앱을 닫더라도 프로세스가 꼬이지 않고 홈 화면으로 자연스럽게 빠지도록 합니다. 다시 앱 아이콘을 누르면 즉시 1초 만에 화면이 복구됩니다.

---

### 3. "장치 연결 해제" 시 재스캔 불가 현상 수정 (무한루프 꼬임)
* 설정 화면에서 "연결 해제"를 눌렀을 때, 자바스크립트 채널이 `manualDisconnect()`가 아닌 일반 `disconnect()`를 호출하여, **'앱은 끊어졌다고 생각하는데 백그라운드에서는 15초마다 재연결을 시도하는 좀비 상태'**가 되어 블루투스 스캔 모듈을 마비시키는 현상을 고칩니다.

#### [MODIFY] [ble_service_interface.dart](file:///e:/projects/healus/lib/services/ble/ble_service_interface.dart) 및 구현체들
- 인터페이스에 `Future<void> manualDisconnect()` 규격을 공식 추가하고 모든 구현체가 지원하도록 통일합니다.

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- 웹뷰 컨트롤러의 `disconnectDevice` 메시지 핸들러에서 `ref.read(bleServiceProvider).disconnect()`로 되어 있는 코드를 `manualDisconnect()`로 변경하여, 명시적 해제 시 영구 저장소(MAC 주소)와 타이머가 완벽하게 파괴되도록 수정합니다.

#### [MODIFY] [ble_service_provider.dart](file:///e:/projects/healus/lib/services/ble/ble_service_provider.dart)
- 타이머 중복 생성 방지: `!connected` 신호가 들어왔을 때 이미 타이머가 돌고 있다면 무시하도록 `_autoReconnectTimer?.isActive` 체크 로직을 보강합니다.

## Verification Plan
### Manual Verification
1. **거리 이탈 및 UI 복구 테스트**: 멀리 떨어져서 긴급정지를 누른 뒤 연결이 끊어지면, "주입 중" 표시가 10초 내외로 즉각 사라지고 대기 화면으로 돌아오는지 확인. 그 후 기기 근처로 다가갔을 때 15초 내에 스스로 재연결되는지 확인.
2. **최소화 테스트**: 대시보드에서 뒤로가기를 2번 누르면 앱이 '종료'되는 것처럼 홈으로 나가집니다. 이 후 바탕화면에서 Healus 아이콘을 눌렀을 때 딜레이 없이 즉시 대시보드가 열리는지 확인.
3. **명시적 해제 테스트**: 장치 해제를 누르면 스캔 리스트 화면으로 돌아가고, 곧바로 다른 장치를 선택해 정상적으로 연결을 진행할 수 있는지 확인.
