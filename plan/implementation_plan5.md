# 장치 연결 화면 문구 한 줄 정렬 및 식사 설정 연동 구현 계획서

`ble_connect` (장치 연결) 화면의 경고 문구를 한 줄로 정렬하고, '식사 설정'에서 저장한 아침/점심/저녁 인슐린 양을 '식사 주입' 및 '회식 적용' 화면에 로컬 스토리지를 통해 유기적으로 자동 적용하는 구현 방안을 정의합니다.

## User Review Required

> [!IMPORTANT]
> - **장치 연결 화면 문구 한 줄 처리**: 기존 경고 문구가 화면 폭에 비해 길어 자동 줄바꿈되는 현상을 해결합니다. 텍스트 폰트 크기를 약간 줄이고(`text-body-md` -> `text-[13px]`) `whitespace-nowrap`을 추가하여 390px 모바일 레이아웃 내에서 한 줄에 핏하게 위치하도록 조정합니다.
> - **로컬 스토리지 기반 데이터 공유**: '식사 설정'에서 수정한 값이 브라우저의 `localStorage`('meal_settings')에 정상 저장되므로, 이를 '식사 주입'과 '회식 적용' 화면의 HTML/React 컴포넌트 마운트 시점에 로드하여 입력값 및 대시보드 연동 페이로드(payload)에 자동으로 적용합니다.

## Proposed Changes

### [UI and Application Core]

---

#### [MODIFY] [ble_connect/code.html](file:///e:/projects/healus/ui_design/ble_connect/code.html)
- 경고 문구 엘리먼트(`<p className="text-on-error-container text-body-md font-medium mt-1">`)의 클래스를 `text-[13px] whitespace-nowrap`으로 수정하여 390px 화면 내에서 단일 행으로 완전히 탑재시킵니다.

---

#### [MODIFY] [meal_injection/code.html](file:///e:/projects/healus/ui_design/meal_injection/code.html)
- React 컴포넌트(`MealInjectionScreen`) 내부에서 `breakfast`, `lunch`, `dinner` 상태를 선언합니다.
- `useEffect` 훅을 추가하여 컴포넌트 로딩 시 로컬 스토리지의 `meal_settings` 값을 파싱해와 해당 상태들에 매핑합니다.
- 아침, 점심, 저녁 입력 `<input>` 태그의 `defaultValue` 및 `placeholder` 대신 React `value` 속성으로 상태를 동적 바인딩합니다.
- "주입하기" 클릭 시 생성되는 `payload` 객체에 고정 수치 대신 상태값을 대입하여 대시보드로 전달되도록 구현합니다.

---

#### [MODIFY] [dining/code.html](file:///e:/projects/healus/ui_design/dining/code.html)
- 아침, 점심, 저녁 설정값의 `<input>` 태그에 각각 `id="breakfast-val"`, `id="lunch-val"`, `id="dinner-val"` 속성을 추가합니다.
- 자바스크립트의 `DOMContentLoaded` 리스너 초입 부분에서 로컬 스토리지의 `meal_settings` 값을 로드한 후, 해당하는 ID를 가진 입력 필드들의 `value`에 세팅해 줍니다.
- "회식적용" 버튼을 누를 때 생성되는 대시보드 `payload`에 설정된 시간 정보뿐만 아니라 함께 적용되는 아침/점심/저녁 설정 단위수도 함께 포함되도록 스크립트를 강화합니다.

---

## Verification Plan

### Automated / Manual Tests
1. **에뮬레이터 구동 및 화면 검증**:
   - `flutter run`으로 기기를 띄우고 장치 연결 화면으로 진입합니다.
   - "서비스를 이용하려면 장치 연결이 필요합니다" 문구가 잘림이나 개행 없이 가로 한 줄에 완전히 매끄럽게 표시되는지 확인합니다.
2. **식사 설정 변경 테스트**:
   - 대시보드 진입 후 `설정 -> 식사 설정`으로 이동합니다.
   - 아침, 점심, 저녁 설정 값을 각각 임의의 값(예: 아침 2.50U, 점심 3.10U, 저녁 4.00U)으로 조정한 뒤 "저장"을 클릭합니다.
3. **식사 주입 화면 확인**:
   - 대시보드에서 `식사 주입` 팝업/화면을 클릭하여 진입합니다.
   - 아침, 점심, 저녁 입력란에 직전에 설정한 수치들이 자동으로 적용되어 있는지 확인합니다.
4. **회식 적용 화면 확인**:
   - 대시보드에서 `회식 적용` 화면으로 진입합니다.
   - 아침설정 값, 점심설정 값, 저녁설정 값 입력창에 직전에 설정한 수치들이 연동되어 잘 노출되는지 확인합니다.
