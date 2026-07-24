# 웹 대시보드 보안 통신 및 데이터 연동 계획

지금까지 대시보드는 "testuser@healus.com" 이라는 고정된 더미 이메일 파라미터를 통해 임시로 데이터를 불러오고 있었습니다. 이제 우리가 만든 **JWT 로그인 인증 체계**를 대시보드에 완벽하게 결합하여, 실제 로그인한 유저의 데이터만 불러오도록 보안 통신을 연동합니다.

## User Review Required
> [!NOTE]
> 이 작업이 완료되면, 로그인을 거치지 않고 강제로 `/dashboard` URL로 접근하는 경우 서버가 데이터를 주지 않고 프론트엔드가 자동으로 `/login` 화면으로 튕겨내게(Redirect) 됩니다. 실제 서비스와 동일한 보안 수준이 적용됩니다.

## Proposed Changes

### 백엔드 (healus-backend)
#### [NEW] `api/deps.py` (또는 `auth.py` 내 추가)
- 클라이언트(웹)가 보낸 API 요청의 헤더(`Authorization: Bearer <토큰>`)를 검증하여 해당 유저 객체를 반환하는 `get_current_user` 의존성을 생성합니다.
- **[테스트 및 샘플 유지 기능]**: 만약 토큰이 없거나 유효하지 않은 경우 에러를 뱉는 대신, 기본 임시 계정(`testuser@healus.com`) 객체를 반환하도록 예외 처리(Fallback)를 둡니다. 이를 통해 로그인하지 않은 방문자도 샘플 대시보드를 볼 수 있게 유지합니다.

#### [MODIFY] `api/web.py`
- 기존의 `/dashboard`, `/ai-insight`, `/bg-log` 엔드포인트들이 파라미터 대신 `Depends(get_current_user)`를 사용하도록 변경합니다.
- 대신 `Depends(get_current_user)`를 사용하여, **토큰 인증을 통과한 진짜 유저의 데이터만** DB에서 꺼내어 응답하도록 수정합니다.

---

### 프론트엔드 (healus-web)
#### [MODIFY] `src/pages/Dashboard.tsx`
- Axios 설정(`api.defaults.headers`)에 로컬 스토리지(`localStorage`)에 저장된 `access_token`이 있다면 탑재하여 백엔드로 보냅니다.
- API 호출 시 `?email=...` 파라미터를 제거합니다.
- 토큰이 없거나 에러가 발생해도 `/login`으로 강제 이동시키지 않고 그대로 두어 백엔드가 주는 **샘플 데이터(testuser)**가 화면에 렌더링되도록 허용합니다. (테스트 아이디/비번 안내는 `Login.tsx`에 그대로 유지됩니다.)

---

## Verification Plan
이 작업이 끝나면 다음과 같이 테스트합니다.
1. **샘플 모드 테스트**: 브라우저 시크릿 모드(로그인 안 한 상태)에서 `/dashboard` 접근 시 튕기지 않고 샘플 데이터(testuser)가 잘 뜨는지 확인
2. **로그인 모드 테스트**: 직접 회원가입/로그인 후 `/dashboard` 접근 시 정상적으로 토큰이 전송되며, 새로 가입한 내 데이터(데이터가 없다면 빈 화면)가 뜨는지 확인
