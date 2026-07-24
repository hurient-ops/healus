# 회원가입 API 및 프론트엔드 연동 계획

웹 대시보드(`healus-web`)의 회원가입 화면에서 입력한 데이터(이름, 이메일, 비밀번호, 펌프 MAC 주소)를 실제 백엔드(`healus-backend`) DB에 저장하기 위한 Full-stack 연동 작업을 진행합니다.

## User Review Required
> [!NOTE]
> 비밀번호는 평문으로 저장되지 않고 `passlib[bcrypt]`를 사용하여 암호화(Hashing)되어 안전하게 DB에 저장됩니다.

## Proposed Changes

### 백엔드 (healus-backend)
#### [MODIFY] `models/schemas.py`
- 클라이언트에서 보내는 회원가입 JSON 데이터를 받을 `UserSignupRequest` Pydantic 모델을 추가합니다.
- 필드: `name`, `email`, `password`, `device_mac`

#### [MODIFY] `api/auth.py`
- 비어있는 파일에 `POST /signup` API 엔드포인트를 신규 작성합니다.
- 데이터베이스 `users` 테이블에 동일한 이메일이나 MAC 주소가 있는지 중복 체크 로직을 포함합니다.
- 비밀번호 해싱 처리 후 DB에 저장합니다.

#### [MODIFY] `main.py`
- `auth.py`의 라우터를 FastAPI `app`에 연결(include_router)합니다. (prefix: `/api/auth`)

---

### 프론트엔드 (healus-web)
#### [MODIFY] `src/pages/Signup.tsx`
- **UI 텍스트 수정**: "기기 뒷면의 S/N 또는 MAC 주소 입력" Placeholder에서 "기기 뒷면의 S/N 또는 " 부분을 삭제하여 직관적으로 MAC 주소만 입력받도록 수정합니다.
- **상태 관리**: `useState`를 사용하여 이름, 이메일, 비밀번호, MAC 주소 입력값을 상태로 관리합니다.
- **이벤트 핸들러**: `onSubmit` 시 기본 동작을 막고 `axios`를 사용해 `http://localhost:8000/api/auth/signup` 으로 POST 요청을 보냅니다.
- **에러 및 성공 처리**: 가입 성공 시 알림 후 로그인(`/login`) 페이지로 이동시키고, 실패 시(예: 중복 이메일) 에러 메시지를 화면에 표시합니다.

## Verification Plan
### Manual Verification
1. 프론트엔드와 백엔드 서버를 모두 실행합니다.
2. 웹의 회원가입 화면에서 임의의 이름, 이메일, 패스워드, 그리고 `device_mac` (예: `00:11:22:AA:BB:CC`)을 입력하고 가입을 누릅니다.
3. 백엔드 `healus.db`의 `users` 테이블에 새로운 UUID를 가진 회원이 정상적으로 Insert 되었는지 로그로 확인합니다.
