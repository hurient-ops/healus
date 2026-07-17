# Healus WebView 흰색 화면(로딩 대기) 버그 수정 계획

Android 17 에뮬레이터 환경에서 로컬 에셋(html)을 웹뷰에 직접 `loadFlutterAsset`으로 로드할 때, 브라우저의 보안 정책(CORS) 제약으로 인해 CDN 및 Babel standalone 컴파일러가 정상적으로 동작하지 못하고 `Cannot use import statement outside a module` 및 `appendChild` 관련 자바스크립트 오류가 발생하여 화면이 흰색으로 멈추는 문제를 해결합니다.

## 제안된 변경 사항

### [Flutter Native]

WebView의 파일 로드 방식을 `loadFlutterAsset`에서 `loadHtmlString` 방식으로 변경하여 보안 제약을 우회합니다. `loadHtmlString` 호출 시 `baseUrl`을 자산 경로로 명시함으로써 로컬 하위 경로 참조 및 외부 CDN 통신이 정상적으로 허용되도록 구성합니다.

#### [MODIFY] [main.dart](file:///e:/projects/healus/lib/main.dart)
- `_initWebViewController` 메서드 내부의 최초 `loadFlutterAsset` 호출부를 `rootBundle.loadString` 및 `loadHtmlString` 방식으로 변경합니다.
- `_loadDashboardPage` 메서드에서도 fallback 동작 시 `loadFlutterAsset` 대신 `loadHtmlString`을 적용하도록 수정합니다.

## 검증 계획

### 수동 검증
1. `flutter run -d emulator-5554`로 앱 재빌드 및 실행
2. 첫 화면(`ble_connect/code.html`)이 흰색 화면에서 멈추지 않고, 블루투스 연결 대기 화면 및 권한 팝업이 에뮬레이터 상에 정상적으로 노출되는지 확인
3. 에뮬레이터 스크린샷 캡처 및 화면 레이아웃 대조를 통해 렌더링 완료 상태를 확인
