# 개인정보 확인/수정 및 회원 탈퇴 기능 구현

본 구현 계획은 healus-web에서 사용자가 자신의 정보를 확인 및 수정하고, 계정을 영구적으로 삭제할 수 있는 전체 워크플로우를 구축하는 것입니다. 요청하신 대로 랜딩 페이지(헤더)에 표시된 사용자 이름과 연계하여 자연스러운 UX를 제공합니다.

## User Review Required

> [!WARNING]
> **Supabase Service Role Key 필요**
> 회원 탈퇴 기능을 안전하게 처리하려면 클라이언트 브라우저가 아닌 백엔드(서버리스 함수)에서 Supabase의 Admin API를 호출해야 합니다. 이를 위해서는 `SUPABASE_SERVICE_ROLE_KEY`가 필요합니다.
> 현재 프로젝트의 `.env.local`에는 해당 키가 없으므로, **기능 구현 시 Vercel 및 로컬 환경변수에 이 키를 추가해 주셔야 합니다.**

## Open Questions

> [!IMPORTANT]
> **탈퇴 시 건강 데이터 처리 정책**
> 사용자가 회원 탈퇴를 할 때, 기존에 펌프에서 올라온 기록(`pump_logs`)이나 혈당 기록(`blood_glucose_logs`)을 모두 함께 영구 삭제(`DELETE`)해야 할까요? 아니면 통계 데이터 활용을 위해 `user_id`를 익명화(NULL 또는 고정된 더미 계정) 처리하여 데이터는 남겨둘까요?
> (답변해주시면 해당 방향으로 구현하겠습니다.)

## Proposed Changes

---

### UI/UX 및 라우팅 추가 (Frontend)

#### [MODIFY] src/components/Header.tsx
- 기존에 이름 클릭 시 바로 `/dashboard`로 이동하던 동작을 **드롭다운 메뉴** 방식으로 변경합니다.
- 이름을 클릭하면 팝업 메뉴가 나타나며 `[대시보드 보기]`, `[개인정보 수정]`을 선택할 수 있도록 개선합니다.

#### [MODIFY] src/App.tsx
- `<Route path="/profile" element={<Profile />} />` 라우팅을 추가합니다.

---

### 개인정보 확인 및 수정 화면 (Frontend)

#### [NEW] src/pages/Profile.tsx
- 사용자의 이름, 생년월일, 연락처, 기기 PID(펌프 ID)를 확인하고 수정할 수 있는 마이페이지 UI 생성.
- **수정 로직**: 
  - `public.users` 테이블의 상세 정보를 업데이트.
  - 비밀번호 변경이 필요한 경우 `supabase.auth.updateUser({ password: '...' })` 호출.
  - 이름 변경 시 Auth 메타데이터의 이름도 동시 업데이트.
- 화면 최하단에 붉은색 텍스트/버튼으로 **'회원 탈퇴'** 영역을 분리하여 배치. 탈퇴 클릭 시 재확인 모달 창 표시.

---

### 회원 탈퇴 처리 백엔드 (Serverless API)

#### [NEW] api/delete-account.ts
- 프론트엔드에서 회원 탈퇴 요청을 받으면 실행되는 Vercel Serverless Function.
- Authorization 헤더로 넘어온 JWT 토큰을 확인해 요청한 사용자의 `uid`를 안전하게 식별.
- (옵션) 사용자와 연관된 데이터를 삭제 또는 익명화 처리.
- `supabase.auth.admin.deleteUser(uid)`를 호출하여 Supabase 인증 서버에서 계정을 영구적으로 삭제.
- 정상 삭제 시 클라이언트에서는 `supabase.auth.signOut()`으로 세션을 비우고 로그인 화면으로 리다이렉트.

## Verification Plan

### Manual Verification
1. 헤더 우측 상단의 [회원 이름]을 클릭 시 드롭다운 메뉴가 정상적으로 뜨는지 확인.
2. [개인정보 수정] 클릭 시 기존 가입 정보가 폼에 정확히 채워지는지 확인.
3. 기기 PID 등 정보를 수정하고 '저장' 클릭 후, 다른 페이지를 다녀왔을 때 변경된 정보가 유지되는지 확인.
4. 회원 탈퇴를 진행했을 때, 계정이 정상적으로 삭제되고 재로그인이 불가능한지 검증.
