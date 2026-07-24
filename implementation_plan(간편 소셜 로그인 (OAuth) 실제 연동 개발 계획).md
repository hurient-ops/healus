# 간편 소셜 로그인 (OAuth) 실제 연동 개발 계획

요청하신 대로 카카오, 네이버, 구글의 '실제' 간편 회원가입/로그인 연동을 개발하기 위한 구조를 설계했습니다.

## ⚠️ User Review Required (중요 안내)

> [!WARNING]
> **실제 서비스 연동을 위해서는 각 포털(카카오, 네이버, 구글)의 개발자 센터에서 '앱 등록'을 통해 고유한 `Client ID`와 `Client Secret`을 발급받아야만 완벽하게 동작합니다.**
> 
> 이번 개발에서는 **가장 표준적이고 실제 서비스에 바로 적용할 수 있는 완벽한 서버/클라이언트 OAuth 인증 흐름(Flow)**을 구축해 드립니다. 임시 키(Mock Key)를 넣어두기 때문에 실제 로그인 화면으로 넘어가면 포털 측에서 "등록되지 않은 앱"이라는 에러가 뜰 수 있습니다. 추후 실제 발급받으신 키만 파일에 덮어쓰시면 즉시 100% 정상 작동하는 구조입니다. 이 방식으로 진행해도 괜찮을까요?

## Proposed Changes

### 1. 백엔드 (FastAPI)
#### [MODIFY] `E:\projects\healus-backend\main.py`
- 백엔드에 OAuth 인증을 처리할 2개의 API 라우터를 추가합니다.
  - `GET /api/auth/login/{provider}` : 클라이언트를 카카오/네이버/구글의 실제 로그인 페이지로 리다이렉트합니다.
  - `GET /api/auth/callback/{provider}` : 사용자가 로그인을 마치고 돌아오면 인증 코드(Code)를 받아 실제 액세스 토큰으로 교환하고, 유저 정보를 조회한 뒤 DB에 유저를 생성/로그인시킵니다.
  - 처리가 완료되면 프론트엔드의 대시보드로 다시 리다이렉트합니다. (`http://localhost:5173/dashboard?token=...`)

#### [MODIFY] `E:\projects\healus-backend\models\models.py`
- 기존 `User` 테이블에 소셜 로그인 유저를 구분하기 위한 컬럼을 추가합니다.
  - `provider` (예: "kakao", "naver", "google")
  - `provider_id` (소셜 플랫폼이 제공하는 고유 회원 번호)

### 2. 프론트엔드 (React)
#### [MODIFY] `E:\projects\healus-web\src\pages\Signup.tsx`
- 기존에 껍데기만 있던 3개의 버튼(카카오, 네이버, 구글)에 `onClick` 이벤트를 부여하여 백엔드의 실제 인증 시작 엔드포인트(`http://localhost:8000/api/auth/login/kakao` 등)로 이동하도록 수정합니다.
- 좌측 상단 "Healus" 로고 클릭 시 홈(`/`)으로 이동하도록 이미 반영을 완료했습니다.

#### [MODIFY] `E:\projects\healus-web\src\pages\Login.tsx`
- 로그인 페이지 하단 등에도 소셜 로그인 버튼을 추가하여 동일한 인증 흐름을 타게 할 수 있습니다. (선택)

## Verification Plan

### Manual Verification
1. 프론트엔드의 '카카오로 시작' 버튼을 누릅니다.
2. 백엔드를 거쳐 **실제 카카오 로그인(accounts.kakao.com) 웹페이지로 리다이렉션** 되는지 확인합니다.
3. (키 발급 전이므로 카카오 측 에러가 뜨는 것이 정상이며, URL이 실제 카카오 서버를 가리키는지 확인합니다.)
4. 추후 발급받으신 진짜 키를 입력하시면 정상적으로 프로필 정보를 가져오고 DB에 회원이 가입되는 것까지 완벽히 동작합니다.
