# 클라우드 아키텍처 마이그레이션 계획 (Vercel + Supabase + Groq)

현재 파이썬(FastAPI) 및 로컬 데이터베이스(SQLite) 기반의 Healus 플랫폼을 글로벌 표준 서버리스 아키텍처로 전면 개편합니다.

## User Review Required

> [!WARNING]
> 이 마이그레이션이 완료되면 기존의 파이썬 백엔드(`healus-backend`)는 더 이상 사용되지 않으며, 프론트엔드(`healus-web`)가 직접 클라우드 데이터베이스(Supabase)와 클라우드 AI(Groq)와 통신하게 됩니다. 
> 
> **사전에 발급받으신 Groq API 키를 리뷰 승인 시 꼭 채팅창에 함께 남겨주세요.**

## Open Questions

> [!NOTE]
> 기존 로컬 `app.db`에 저장되어 있던 테스트 데이터는 클라우드로 옯기지 않고, Supabase에서 새롭게 테이블을 만들어 깔끔하게 다시 시작해도 괜찮을까요?

## Proposed Changes

### 1. Supabase 데이터베이스 구축 (SQL)
현재 `models.py`에 정의된 4개의 테이블을 Supabase의 PostgreSQL에 맞게 생성합니다.
- `users`: 이메일 인증과 연동되는 회원 테이블 (전화번호, 생년월일, 펌프 PID 포함)
- `pump_logs`: 인슐린 주입 로그
- `raw_packet_logs`: 기기 통신 패킷 로그
- `blood_glucose_logs`: 혈당 로그
- 보안을 위한 **RLS(Row Level Security)** 정책 적용 (본인의 데이터만 조회 가능)

### 2. 프론트엔드(healus-web) 전면 개편
#### [NEW] `.env`
- 환경변수 파일 생성 (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY 등)
#### [NEW] `src/lib/supabase.ts`
- `@supabase/supabase-js` 라이브러리를 통해 클라우드 DB 연결 객체 생성
#### [MODIFY] `src/pages/Signup.tsx` & `Login.tsx`
- 기존 파이썬 API 호출을 제거하고 `supabase.auth`를 이용한 회원가입/로그인 로직으로 교체
#### [MODIFY] `src/pages/Dashboard.tsx`, `Diet.tsx` 등
- 파이썬 API 대신 Supabase DB에서 데이터를 직접 Select 하도록 변경

### 3. Groq AI 연동 (Vercel Serverless Function)
Groq API 키를 브라우저에 노출시키면 안 되므로, Vercel의 서버리스 함수 기능을 이용해 안전한 백엔드를 프론트엔드 폴더 내에 구축합니다.
#### [NEW] `api/chat.ts`
- Vercel Serverless Function으로 동작하며, 프론트엔드의 요청을 받아 Groq API(llama-3.3-70b-versatile)를 호출하고 결과를 반환합니다.
#### [MODIFY] `src/components/AIChatWidget.tsx`
- 기존 파이썬 백엔드(/api/web/chat) 대신 새롭게 만든 `/api/chat` 서버리스 함수를 호출하도록 변경합니다.

## Verification Plan

### Automated Tests
- TypeScript 타입 검사 통과 여부 확인
- Vite 빌드(build) 정상 완료 확인

### Manual Verification
- 새로 만든 Supabase 계정으로 실제 웹페이지에서 회원가입 및 로그인이 되는지 테스트
- 대시보드 화면 렌더링 확인
- AI 챗봇에게 질문하여 Groq 모델(Llama 3.3)이 1초 이내에 정상적으로 답변을 반환하는지 테스트
