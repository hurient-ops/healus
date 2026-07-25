# 기기 연동 방식 변경 마이그레이션 최종 계획

현재 Healus 플랫폼은 인슐린 펌프 식별자로 `device_mac` (MAC 주소)를 사용하도록 설계되어 있습니다. 하지만 iOS 블루투스 정책 및 **이메일 계정이 없는 모바일 앱(펌프 컨트롤러)**의 특성을 고려하여, 식별자를 **펌프 내부의 고유 PID (Pump_ID, 16byte)**로 전면 전환하고 회원가입 폼을 강화합니다.

## User Review Required

> [!IMPORTANT]
> 본 작업은 백엔드의 데이터베이스 스키마와 API 스펙을 변경하는 **파괴적 변경(Breaking Change)**입니다.
> 기존 테스트 데이터베이스(`app.db`)가 삭제 및 초기화(재생성)되며, 프론트엔드와 백엔드의 필드명이 일괄 변경됩니다. 진행해도 괜찮으신지 최종 확인 부탁드립니다.

## 핵심 아키텍처 변경 사유

> [!NOTE]
> **왜 웹에서 PID를 무조건 입력해야 하는가?**
> 현재 개발 중인 모바일 앱(펌프 통신 앱)은 이메일 로그인 없이 단순 비밀번호(PIN)만으로 진입합니다. 따라서 모바일 앱이 서버로 데이터를 보낼 때 유일하게 보낼 수 있는 식별자는 **'PID'**뿐입니다.
> 사용자가 웹(Web) 대시보드에서 자신의 데이터를 보려면 웹 계정(이메일)과 모바일 앱 데이터(PID)를 연결해주는 고리가 필요한데, 그 유일한 방법이 **웹 회원가입 시 PID를 필수로 입력받아 DB에 매칭해두는 것**입니다.

---

## Proposed Changes (수정 작업 계획)

### 1. 백엔드 (healus-backend) 변경

#### [MODIFY] models/models.py
- `device_mac` 필드를 `pump_id`로 이름 변경. (모든 관련 테이블 적용)
- `User` 모델에 신규 필수 컬럼 추가:
  - `phone_number = Column(String, nullable=False)` (전화번호)
  - `birth_date = Column(String, nullable=False)` (생년월일, 예: YYYY-MM-DD 형식)
  - `terms_agreed = Column(Boolean, nullable=False, default=False)` (개인정보/민감정보 수집 동의 여부)

#### [MODIFY] models/schemas.py
- `UserSignupRequest`에 신규 필수 필드 추가: `phone_number`, `birth_date`, `terms_agreed`.
- `device_mac`을 `pump_id`로 일괄 변경.

#### [MODIFY] api/auth.py & api/logs.py
- 회원가입 API 로직에 신규 필드(핸드폰, 생년월일, 동의여부) 유효성 검사 및 저장 로직 추가.
- `device_mac` 기반 쿼리를 `pump_id` 기반 쿼리로 업데이트.

#### [MODIFY] seed_data.py
- DB 초기화 시 신규 컬럼(`phone_number`, `birth_date`, `terms_agreed`)에 대한 더미 데이터 생성 코드 추가.
- PID 가상 데이터 적용 (예: `1234567890ABCDEF`).

### 2. 프론트엔드 (healus-web) 변경

#### [MODIFY] src/pages/Signup.tsx
- **신규 필수 입력 필드 추가**:
  - `생년월일 (YYYY-MM-DD)`
  - `핸드폰 번호 (010-XXXX-XXXX)`
- **PID 입력칸 수정 및 필수(Required) 지정**:
  - 라벨을 `기기 PID (Pump ID)`로 변경.
  - 설명: `모바일 앱에서 전송된 데이터를 확인하기 위해 펌프의 16byte 고유 식별자를 반드시 입력해 주세요.`
- **개인정보 동의 체크박스 추가**:
  - `[필수] 개인정보 및 민감정보(건강정보) 수집 및 이용에 동의합니다.`
  - 동의 체크박스를 선택하지 않으면 폼 제출(계정 만들기) 버튼 비활성화.
- 향후 API 연동을 위해 폼 상태(`useState`)에 해당 필드들을 모두 정의.

---

## Verification Plan

### Automated Tests
- 코드 내 일괄 변경 적용 후 구문(Syntax) 및 타입스크립트 빌드 오류가 없는지 확인합니다.

### Manual Verification
1. 백엔드 `seed_data.py`를 실행하여 새로운 스키마로 DB 재생성 및 초기 데이터가 정상 주입되는지 확인합니다.
2. 프론트엔드 회원가입(`Signup.tsx`) 화면에 생년월일, 전화번호, 필수 PID 입력창, 동의 체크박스가 기획 의도대로 잘 렌더링되는지 확인합니다.
3. 백엔드 API 서버를 띄우고 Swagger(`/docs`)에서 `pump_id`, `phone_number`, `birth_date`, `terms_agreed` 파라미터가 필수로 설정되어 있는지 확인합니다.
