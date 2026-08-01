# 이용약관, 개인정보처리방침, 고객센터, FAQ 구현 완료

요청하신 4가지 정보성/지원 페이지와 이들을 손쉽게 탐색할 수 있는 공통 푸터(Footer)의 구현이 성공적으로 완료되었습니다!

## 🛠 주요 구현 내역

### 1. 공통 푸터(Footer) 및 통합 링크 적용
* `[NEW] Footer.tsx`가 신설되어, 메인 홈화면 및 모든 약관/지원 페이지의 하단에 일관되게 노출됩니다.
* 기존 `Home.tsx` 하단에 있던 링크들을 새로 생성된 `/terms`, `/privacy`, `/faq`, `/support` 라우팅으로 올바르게 연결했습니다.

### 2. 정적 정보 페이지
* **이용약관 (`/terms`)**: 회원 가입 및 서비스 제공에 대한 기본적인 권리와 의무를 명시하는 표준 약관 텍스트를 배치했습니다. (의료기기가 아닌 보조 도구임을 명확히 안내하는 조항 포함)
* **개인정보처리방침 (`/privacy`)**: 수집 항목(혈당기록, 펌프 ID 등) 및 탈퇴 시 데이터 익명화 보존 정책을 법적인 형태의 안내문으로 구성했습니다.

### 3. 사용자 지원 페이지
* **FAQ (`/faq`)**: 아코디언 방식의 UI를 적용하여 부드럽고 가독성 좋게 자주 묻는 질문들을 나열했습니다. (펌프 연동 방법, 데이터 동기화, PID 확인 방법 등)
* **고객센터 (`/support`)**: 
  - 상단에 전화 상담, 운영 시간, 이메일 주소를 시각적으로 안내합니다.
  - 하단에 **1:1 문의 폼**을 구성했습니다. 로그인된 사용자의 경우 이메일이 자동으로 채워지며, 제출 시 백엔드 API를 통해 Supabase DB로 저장되도록 설계했습니다.

## 🚨 사용자 조치 필요 (데이터베이스 테이블 생성)
1:1 문의 내용이 저장될 테이블을 Supabase에 생성해야 합니다. 
프로젝트 루트 경로에 `inquiries.sql` 파일을 생성해 두었습니다. 해당 파일의 내용을 **Supabase의 SQL Editor**에 복사/붙여넣기 하신 뒤 **RUN**을 눌러 실행해 주시기 바랍니다.

```sql
-- inquiries.sql 내용 중 일부
CREATE TABLE IF NOT EXISTS public.inquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    email VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    status VARCHAR(50) DEFAULT '대기중',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## ✅ 검증 결과
* TypeScript 빌드 오류 없이 깔끔하게 컴파일 완료(`npm run build` 통과).
* Vercel 배포를 위해 GitHub 푸시 완료.
