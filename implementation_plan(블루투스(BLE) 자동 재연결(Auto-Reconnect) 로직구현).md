# [Goal Description]
Healus 모바일 앱에 **블루투스(BLE) 자동 재연결(Auto-Reconnect)** 로직을 완벽하게 구현하여, 환자가 펌프와 멀어지거나 앱 프로세스가 잠시 종료되더라도 24시간 끊김 없이 데이터를 동기화할 수 있도록 방어벽을 구축합니다.

## User Review Required
> [!IMPORTANT]
> **패키지 추가 안내**
> 기기의 고유 식별자(Android: MAC, iOS: UUID)를 앱이 종료되어도 기억하도록 영구 저장소 패키지(`shared_preferences`)를 추가합니다.
>
> **테스트 모드 처리 방식 변경**
> 기존에는 연결이 끊기면 임의로 '테스트 모드(가상 펌프)'로 전환되게 되어 있었습니다. 이제는 실제 기기 환경에서 연결이 끊기면 '테스트 모드'로 가는 것이 아니라, **'연결을 복구하기 위해 백그라운드에서 15초마다 재연결을 시도하는 루프 상태'**로 전환되도록 로직을 수정합니다.

## Proposed Changes

### 1. 패키지 의존성 추가 (pubspec.yaml)
* 기기 식별자 영구 저장을 위한 `shared_preferences` 추가.

#### [MODIFY] [pubspec.yaml](file:///e:/projects/healus/pubspec.yaml)
- `shared_preferences: ^2.2.0` 추가

---

### 2. 기기 식별자(ID) 영구 저장 및 iOS 호환성 확보
#### [MODIFY] [ble_service_provider.dart](file:///e:/projects/healus/lib/services/ble/ble_service_provider.dart)
- **식별자 저장**: `connect(deviceId)` 성공 시 `SharedPreferences`에 해당 ID를 저장합니다.
- **iOS MAC 주소 은닉 대응**: iOS는 보안상 MAC 주소를 제공하지 않고 기기마다 고유한 UUID를 발급합니다. 하지만 우리가 사용하는 `flutter_blue_plus` 패키지는 이를 투명하게 처리하여 `remoteId`라는 공통 속성을 제공합니다. 따라서 **"안드로이드의 MAC 주소"이든 "iOS의 UUID"이든 구분하지 않고 `remoteId.str` 값을 그대로 저장하고 재연결 시 불러와 사용**하면 양쪽 OS 모두 문제없이 동작합니다.
- **비밀번호(PIN) 재입력 문제**: 최초 연결 시 OS 단에서 '페어링(Bonding)'이 완료되면 펌프의 암호키가 OS에 저장되므로, 이후 백그라운드에서 코드로 재연결을 시도할 때는 비밀번호 팝업이 다시 뜨지 않고 자동으로 통과됩니다.

---

### 3. 명시적 연결 해제 vs 비정상 단절 구분 로직
#### [MODIFY] [ble_service_provider.dart](file:///e:/projects/healus/lib/services/ble/ble_service_provider.dart)
- `disconnect()` 메서드를 두 가지로 분리합니다.
  1. `manualDisconnect()`: 앱 설정 화면에서 사용자가 **"장치 연결 해제"** 버튼을 명시적으로 눌렀을 때 호출. `SharedPreferences`에서 기억된 기기 ID를 완전히 삭제하고, 재연결 타이머를 끕니다.
  2. 비정상 연결 끊김 감지: 블루투스가 멀어지거나 `connectionState`가 `disconnected`로 떨어지면, `SharedPreferences`에 저장된 ID가 남아있으므로 `_autoReconnectTimer` (15초 간격)를 즉시 가동하여 스스로 `connect(저장된ID)`를 무한 시도합니다.

---

### 4. 앱 시작 시 및 뒤로가기 종료(Background) 시 처리
#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- `initState`에서 앱이 켜지자마자 `SharedPreferences`를 조회하여 저장된 기기 ID가 있다면 스캔 화면을 띄우지 않고 곧바로 백그라운드 재연결 루프를 시작합니다.
- **뒤로가기 2번 종료 시**: 앱이 명시적으로 시스템 킬(Kill) 당하거나 닫히더라도, 사용자가 "장치 연결 해제"를 누른 것이 아니므로 기기 ID는 지워지지 않습니다. 따라서 다음번에 앱을 켜면(혹은 포그라운드 서비스가 앱을 부활시키면) 즉시 재연결을 수행하여 통신을 이어갑니다.

## Verification Plan
### Manual Verification
1. **거리 이탈 자동 복구 테스트**: 
   - 펌프 기기와 연결한 상태에서 폰을 들고 10m 밖으로 나가 연결을 끊습니다.
   - 앱이 스스로 15초 단위로 재연결을 시도하는지 디버그 로그로 확인합니다.
   - 다시 기기 근처로 돌아왔을 때, 펌프와 폰이 PIN 번호 입력 없이 즉시 착 달라붙고 배터리 타이머가 부활하는지 확인합니다.
2. **뒤로가기 강제 종료 테스트**: 
   - 펌프가 연결된 상태에서 뒤로가기 2번을 눌러 앱을 종료합니다. 
   - 앱을 다시 켰을 때(스캔 다이얼로그 조작 없이) 이전에 기억해 둔 펌프로 즉각 연결되는지 확인합니다.
3. **명시적 장치 해제 테스트**:
   - 설정 화면에서 "장치 연결 해제" 버튼을 누릅니다.
   - 앱이 재연결을 시도하지 않고 깨끗하게 끊어진 상태를 유지하는지 확인합니다.
