# Healus Web 구현 및 백엔드 연동 계획

React 컴포넌트를 개발하고, 기존 `healus-backend` 서버와 데이터를 주고받을 수 있도록 연동하는 전체 구현 계획입니다.

## 1. 프론트엔드 (healus-web) 구현 계획

Stitch로 생성된 4개의 UI 시안을 실제 React 컴포넌트로 구현합니다.
- **초기 메인화면 디자인 생성 (Stitch AI):** 
  - 코딩 전, "Healus AI 당뇨관리 플랫폼"이라는 제목과 함께 카카오 파스타(PASTA) 및 Tidepool의 레이아웃을 참고한 랜딩 페이지 시안을 Stitch AI로 새롭게 생성하여 디자인을 우선 확정합니다.
- **라우팅 설정:** `react-router-dom`을 사용하여 각 페이지를 연결합니다.
- **디자인 시스템 적용:** `index.css`에 확정된 테마(색상, 폰트, 간격)를 설정합니다.
- **페이지 컴포넌트 개발:**
  - `Home.tsx` (비회원 홈 화면 - `/` 기본 경로)
    - 확정된 Stitch 시안을 바탕으로 랜딩 페이지를 구현합니다.
  - `Article.tsx` (당뇨 지식 가이드 화면)
  - `Dashboard.tsx` (회원 대시보드 화면)
    - **AI 분석 연동:** 백엔드의 `llama-3.1-storm-8b` 추론 엔진(또는 추후 Groq API)과 연동하여, 환자의 최근 주입/혈당 데이터를 기반으로 분석된 '맞춤형 AI 주치의 인사이트(3줄 요약)'를 대시보드 상단 또는 주요 위젯으로 눈에 띄게 배치합니다.
  - `BgLogModal.tsx` (혈당 수동 입력 화면)
- **API 연동 모듈:** `axios` 또는 `fetch`를 활용하여 백엔드와 통신하는 함수(`api.ts`)를 작성합니다.

## 2. 백엔드 (healus-backend) API 확장 계획

현재 백엔드(`main.py`, `api/logs.py`)에는 펌프 기기에서 데이터를 '저장(POST)'하는 API만 존재합니다. 웹 화면을 띄우기 위해서는 데이터를 '가져오는(GET)' API와 혈당을 수동으로 저장하는 API가 추가로 필요합니다.

- **데이터베이스 모델 추가 (`models/models.py`)**
  - `BloodGlucoseLog`: 수동으로 입력한 혈당 수치, 측정 시간, 식전/식후 상태(태그)를 저장하는 테이블 추가.
- **웹 전용 API 라우터 추가 (`api/web.py` 생성)**
  - `GET /api/web/dashboard`: 대시보드 차트에 그릴 데이터(오늘의 인슐린 총량, 시간대별 혈당 점 데이터)를 반환하는 API.
  - `GET /api/web/ai-insight`: 로컬 `llama-3.1-storm-8b` 모델(향후 Groq 전환 가능)을 호출하여 환자 데이터 기반 3줄 요약 조언을 반환하는 API.
  - `POST /api/web/bg-log`: 혈당 수동 입력 화면에서 전송한 데이터를 DB에 저장하는 API.

## 3. 통합 및 테스트 (Integration)

- `healus-web`에서 띄운 대시보드에 백엔드의 가짜(Mock) 데이터를 먼저 연결하여 그래프가 잘 나오는지 테스트합니다.
- 수동으로 혈당을 입력하고 저장 버튼을 눌렀을 때, 백엔드 DB(`healus.db`)에 정상적으로 기록되는지 확인합니다.

---

> [!IMPORTANT]
> **사용자 검토 요청 (User Review Required)**
> 1. 백엔드(FastAPI)에 웹 전용 API를 추가하는 방향에 동의하시나요?
> 2. 프론트엔드(React) 개발 시 UI 컴포넌트는 빠르게 구현하기 위해 CSS 모듈 또는 TailwindCSS를 사용할 계획입니다. 선호하시는 방식이 있나요? (기본적으로 TailwindCSS 추천)
> 3. 위 계획이 마음에 드신다면 **승인(Proceed)**을 눌러주세요. 프론트엔드/백엔드 코드 작성을 바로 시작합니다!
