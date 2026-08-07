# [Goal Description]
Healus 모바일 앱에 Apple HealthKit(iOS) 및 Google Health Connect(Android) 연동 기능을 추가하여, 환자의 스마트폰에 기록된 CGM(연속혈당측정기) 데이터를 읽어와 Healus-web(웹뷰)으로 전달하는 구조(방법 A)를 구현합니다.

## User Review Required
> [!IMPORTANT]
> **Android Health Connect 권한 심사**
> Google Play 스토어에 앱을 출시할 때, Health Connect에서 의료 데이터(혈당)를 읽어오는 권한은 민감한 권한으로 분류되어 Google의 별도 심사(앱의 개인정보처리방침 및 사용 목적 소명)를 통과해야 합니다.
> 
> **iOS HealthKit 심사**
> App Store 심사 시, 왜 건강 데이터를 사용하는지에 대한 명확한 설명과 프라이버시 정책이 필요합니다.

## Open Questions
> [!WARNING]
> 1. 웹뷰(Healus-web)에서 네이티브(Flutter)로 데이터를 요청하는 방식(JS Channel)을 사용할 계획입니다. 웹 쪽에서 데이터를 받을 준비(API 스펙)가 되어 있으신가요?
> 2. 데이터를 읽어올 기간(예: 최근 24시간, 최근 7일)은 기본적으로 24시간으로 설정해도 괜찮을까요?

## Proposed Changes

### 1. 패키지 의존성 추가 (pubspec.yaml)
* Flutter 공식 커뮤니티에서 가장 널리 쓰이며 iOS/Android 양측을 모두 지원하는 `health` 패키지를 도입합니다.

#### [MODIFY] [pubspec.yaml](file:///e:/projects/healus/pubspec.yaml)
- `health: ^10.0.0` (또는 최신 안정화 버전) 추가

---

### 2. 안드로이드 권한 및 환경 설정 (AndroidManifest.xml)
#### [MODIFY] [AndroidManifest.xml](file:///e:/projects/healus/android/app/src/main/AndroidManifest.xml)
- Health Connect 앱 패키지명 가시성(queries) 추가
- `android.permission.health.READ_BLOOD_GLUCOSE` 권한 추가
- 사용자 개인정보처리방침(Privacy Policy) 페이지로 연결되는 Activity Intent Filter 명시 (Health Connect 필수 규정)

---

### 3. iOS 권한 및 환경 설정 (Info.plist 및 Xcode 프로젝트)
#### [MODIFY] [Info.plist](file:///e:/projects/healus/ios/Runner/Info.plist)
- `NSHealthShareUsageDescription`: "CGM(연속혈당측정기) 데이터를 대시보드에 표시하기 위해 건강 데이터 접근 권한이 필요합니다." 문구 추가
- `NSHealthUpdateUsageDescription` (필요시)

#### [MODIFY] iOS 프로젝트 (수동 설정 필요 항목)
- Xcode 프로젝트에서 `HealthKit` Capability 추가 안내 (플랜 승인 시 가이드 제공)

---

### 4. Flutter 네이티브 혈당 데이터 서비스 계층 구현
#### [NEW] `lib/services/cgm/health_data_service.dart`
- `HealthFactory` 인스턴스 초기화
- `BLOOD_GLUCOSE` 데이터 타입 권한 요청 로직 (`requestAuthorization`)
- 지정된 기간(예: 24시간) 동안의 혈당 데이터를 리스트 형식으로 읽어오는 로직 구현 (`getHealthDataFromTypes`)

---

### 5. Web ↔ Native 브릿지 연결 (main.dart 또는 Bridge 클래스)
#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart) (WebViewController 부분)
- 웹뷰 컨트롤러에 `CgmDataChannel`이라는 JavaScript 채널을 추가
- Healus-web(Javascript)에서 `CgmDataChannel.postMessage('fetchCGM')`을 호출하면:
  1. `health_data_service`를 통해 혈당 데이터 배열을 읽어옴
  2. JSON 형태로 직렬화 `[{ "time": "...", "value": 110.5, "unit": "mg/dL" }, ...]`
  3. `_controller.runJavaScript('window.onCgmDataReceived(...)')`를 통해 웹으로 전달

## Verification Plan
### Manual Verification
1. **권한 팝업 확인**: 앱 실행 및 웹에서 데이터 요청 시 OS 기본 건강 데이터 권한 허용 팝업이 뜨는지 확인.
2. **모의 데이터 테스트**:
   - iOS 시뮬레이터: '건강' 앱에 수동으로 혈당 데이터를 몇 개 입력한 후, Healus 앱에서 해당 데이터를 잘 읽어오는지 테스트.
   - Android 에뮬레이터: Health Connect 앱을 설치하고 모의 혈당 데이터를 입력하여 테스트.
3. **웹 전달 확인**: 네이티브 로그 창과 웹뷰 디버거를 통해 JSON 데이터 패킷이 웹 쪽으로 정상적으로 콜백되는지 확인.
