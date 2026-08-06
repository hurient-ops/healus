# 포그라운드 서비스 및 백그라운드 타이머 안정화 도입 (Background BLE)

현재 HealUs 앱이 백그라운드로 내려가거나 화면이 꺼질 때(OS Doze Mode), 안드로이드/iOS의 절전 정책에 의해 30분 주기의 데이터 폴링 타이머가 무기한 지연되는 현상을 해결합니다. 이를 위해 **Foreground Service(안드로이드)** 및 **Background Mode(iOS)**를 도입하여 앱의 메인 프로세스가 백그라운드에서도 종료되지 않고 살아있도록 구성합니다.

## User Review Required

> [!WARNING]
> **중요한 구조적 변경 사항**
> 안드로이드 정책 상, 포그라운드 서비스를 사용하려면 상단 상태바에 "앱이 백그라운드에서 실행 중"이라는 **고정 알림(Notification)**이 필수적으로 노출되어야 합니다. 또한 안드로이드 14 이상의 최신 정책을 준수하기 위해 `FOREGROUND_SERVICE_CONNECTED_DEVICE` 등의 추가 권한이 매니페스트에 등록됩니다.

## Open Questions

> [!IMPORTANT]
> 알림바에 노출될 고정 알림의 문구(제목 및 내용)는 어떻게 설정할까요?
> (예: 제목: "HealUs", 내용: "인슐린 펌프와 연결을 유지 중입니다.")

## Proposed Changes

---

### 1. 의존성 (Dependencies)
안드로이드의 포그라운드 서비스 구동을 위해 패키지를 추가합니다. 기존 상태 관리(Riverpod)와 BLE 연결 상태를 메인 Isolate에서 그대로 유지하기 위해, 복잡한 백그라운드 Isolate를 새로 띄우기보다는 메인 프로세스를 살려두는 용도로 사용 가능한 `flutter_foreground_task` (또는 유사 패키지)를 활용합니다.

#### [MODIFY] pubspec.yaml
- `flutter_foreground_task: ^6.1.1` (또는 안정 버전) 추가.

---

### 2. 안드로이드 권한 및 매니페스트 설정
포그라운드 서비스 및 알림 권한을 AndroidManifest에 명시합니다.

#### [MODIFY] android/app/src/main/AndroidManifest.xml
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />`
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />`
- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`
- Service 선언 태그 추가.

---

### 3. iOS 백그라운드 권한 설정
iOS 환경에서도 블루투스 연결이 백그라운드에서 끊기지 않도록 `UIBackgroundModes`를 활성화합니다.

#### [MODIFY] ios/Runner/Info.plist
- `UIBackgroundModes` 배열에 `bluetooth-central` 추가.

---

### 4. 타이머 딜레이 및 포그라운드 초기화 (Main App Logic)
기존 타이머가 큐에 동시에 인입되어 패킷 전송이 충돌(누락)하던 문제를 함께 해결하기 위해, 메인 다트 코드에서 타이머 기동 시 딜레이(Offset)를 추가하고, 앱 시작 시 포그라운드 서비스를 실행하도록 연동합니다.

#### [MODIFY] lib/main.dart
- 앱 초기화(main 함수 또는 초기 위젯) 시 `FlutterForegroundTask.init()` 호출 로직 추가.
- `_startQntPollTimer()` 호출 시 `Future.delayed(const Duration(seconds: 10))`의 오프셋 추가를 통해 `_batteryTimer`와 겹치지 않게 분리.
- BLE 연결이 활성화될 때 Foreground Service를 켜고, 명시적으로 연결을 끊거나 앱을 종료할 때 Service 단을 종료하도록 생명주기 연동.

## Verification Plan

### Automated Tests
- 없음

### Manual Verification
1. 앱 빌드 후 인슐린 펌프(또는 에뮬레이터)와 연결.
2. 홈 화면 진입 시 상단 상태바에 고정 알림이 뜨는지 확인.
3. 앱을 백그라운드로 내리고 화면을 끈 상태에서 35분간 대기.
4. 패킷 로그를 통해 30분 주기로 0x70과 0x1E 요청이 정확히 발송되었는지 확인.
