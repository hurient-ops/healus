# [Healus Backend] 통합 아키텍처 및 AI 추론(PoC) 테스트 계획서

사용자님의 훌륭한 비전에 따라 **'비회원 퍼블릭 서비스'**와 **'회원 전용 개인화 AI 서비스'**로 프론트엔드 및 백엔드 아키텍처를 완벽하게 분리하여 고도화합니다. 이 계획서는 백엔드 DB 확장 및 LM Studio 기반의 가상 데이터 AI 테스트에 대한 포괄적인 계획을 담고 있습니다.

## User Review Required

> [!IMPORTANT]
> **LM Studio 설정 확인 사항**
> 1. LM Studio에서 Llama 3.1 모델을 로드해 주세요.
> 2. 좌측 탭에서 **'Local Server (↔ 화살표 아이콘)'** 메뉴로 들어가서 **'Start Server'** 버튼을 켜주셔야 합니다. (기본 포트: `1234`)
> 
> 서버가 켜져 있어야만 제가 작성할 파이썬 스크립트가 해당 포트로 데이터를 보내 추론 결과를 받아올 수 있습니다. 위 사항을 인지하셨다면 이 계획을 승인(Proceed)해 주세요.

---

## Proposed Changes

### 1. 회원/비회원 구분을 위한 DB 모델 확장 (User Mapping)
기존 로그 중심의 DB에 **회원(User) 개념**을 도입하고 기기와 맵핑(Mapping)합니다.

#### [MODIFY] e:\projects\healus-backend\models\models.py
- **`User` 테이블 신설:** 회원가입/로그인을 위한 테이블 (`id`, `email`, `hashed_password`, `name` 등)
- **관계(Relationship) 설정:** 한 명의 회원(`User`)이 자신의 인슐린 펌프(`device_mac`)를 등록하여 소유권을 가지도록 외래키(ForeignKey)를 설정합니다.
- 이에 따라 기존의 `pump_logs`와 `raw_packet_logs` 데이터는 철저하게 **'해당 기기를 등록한 회원'**에게만 종속되어 섞이지 않도록 관리됩니다.

### 2. 회원 인증 (JWT Auth) 및 API 분리 설계
프론트엔드 화면 구성에 맞게 백엔드 API 창구를 '비회원용'과 '회원용'으로 분리합니다.

- **비회원 API (로그인 불필요):** 당뇨 지식, 좋은 음식 소개 등 일반 콘텐츠 제공 API
- **회원 API (JWT 토큰 필수):** 로그인/회원가입, 펌프 기기 등록, 내 펌프 데이터 동기화(`/api/logs`), 내 AI 인사이트 리포트 조회

### 3. LM Studio 연동을 위한 필수 라이브러리 추가
#### [MODIFY] e:\projects\healus-backend\requirements.txt
- LM Studio(OpenAI 호환)와의 통신 및 향후 보안 로그인을 위해 `openai`, `passlib`, `pyjwt` 등의 패키지를 추가합니다.

### 4. 가상 회원 및 더미 데이터(Mock Data) 생성 스크립트
#### [NEW] e:\projects\healus-backend\scripts\generate_mock_data.py
- 테스트를 위해 임의의 가상 회원(`testuser@healus.com`)을 생성하고 특정 펌프 맥어드레스(`MAC_1234`)를 매핑합니다.
- 이 가상 회원의 최근 30일 치 '인슐린 주입 이력'을 무작위로(특정 식습관 패턴을 포함하여) 생성하여 `healus.db`에 주입합니다.

### 5. 회원의 개인화된 AI 추론 (LM Studio Llama 3.1) 스크립트
#### [NEW] e:\projects\healus-backend\scripts\test_ai_inference.py
- DB에서 `testuser@healus.com` 회원이 매핑된 기기의 30일 치 데이터를 불러와 텍스트로 요약합니다.
- `http://localhost:1234/v1` (LM Studio 기본 서버)로 이 데이터를 전송하여 **'해당 회원만을 위한 1:1 맞춤형 주입량 조언 및 식습관 분석 리포트'**를 도출해 내는 프롬프트를 실행합니다.

---

## Verification Plan
1. `models.py`를 업데이트하고 스크립트를 통해 회원 테이블과 기기 매핑 구조가 정상적으로 생성되는지 확인합니다.
2. `generate_mock_data.py`를 실행하여 가상 회원과 그 회원의 30일 치 기기 데이터가 정상적으로 묶여서 DB에 삽입되는지 확인합니다.
3. `test_ai_inference.py`를 실행하여 터미널 창에 LM Studio(Llama 3.1)가 도출해 낸 **'회원 맞춤형 인사이트 리포트 결과'가 한글로 정상 출력**되는지 눈으로 확인합니다.
