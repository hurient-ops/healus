# 로그인 API 연동 및 엔드투엔드 테스트 계획

회원가입 기능에 이어, 웹 대시보드의 **실제 로그인 기능**을 구현하고 테스트까지 진행하는 통합 계획입니다.

## User Review Required
> [!NOTE]
> - 로그인은 보안을 위해 **JWT (JSON Web Token)** 방식을 사용하여 구현합니다.
> - 서버는 임의의 `SECRET_KEY`를 사용하여 토큰을 발급하며, 웹 클라이언트(`healus-web`)는 이를 `localStorage`에 보관하여 로그인 상태를 유지합니다.

## Proposed Changes

### 백엔드 (healus-backend)
#### [MODIFY] `seed_data.py`
- 기존 더미 유저(`testuser@healus.com`)의 비밀번호가 단순 문자열이므로, 로그인이 가능하도록 `passlib`을 사용해 암호화된 `password123`으로 변경 후 DB를 재초기화합니다.

#### [MODIFY] `models/schemas.py`
- 로그인 요청을 받을 Pydantic 스키마 `UserLoginRequest`를 추가합니다 (필드: `email`, `password`).

#### [MODIFY] `api/auth.py`
- `POST /login` 엔드포인트를 신규 작성합니다.
- 이메일로 유저를 조회하고, `passlib`의 `verify` 함수를 사용해 입력된 비밀번호와 DB의 암호화된 비밀번호를 대조합니다.
- 인증 성공 시 `PyJWT`를 사용해 고유한 JWT 토큰을 발급하여 반환합니다.

---

### 프론트엔드 (healus-web)
#### [MODIFY] `src/pages/Login.tsx`
- 화면의 텍스트에 테스트용 계정 안내(`testuser@healus.com` / `password123`)를 추가합니다.
- 기존의 더미(Dummy) 로그인 로직을 삭제합니다.
- `axios`를 사용해 `http://localhost:8000/api/auth/login` 으로 POST 요청을 보냅니다.
- 서버로부터 받은 `access_token`과 사용자 정보(이름, 이메일, MAC 주소)를 `localStorage`에 저장합니다.
- 로딩 상태와 로그인 실패(비밀번호 오류 등) 에러 메시지를 UI에 반영합니다.

---

## Verification Plan
### 통합 테스트 (End-to-End)
이 작업이 끝난 후, 제가 터미널(백그라운드 태스크)을 제어하여 백엔드 서버(FastAPI)와 프론트엔드 서버(Vite)를 동시에 구동시킨 뒤, 직접 로그인 API가 정상 동작하는지 테스트 스크립트를 통해 검증하겠습니다.
