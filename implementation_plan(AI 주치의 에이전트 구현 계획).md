# AI 주치의 에이전트 구현 계획 (AI Chat Agent)

환자의 라이프로그 데이터를 이해하고 대화할 수 있는 **능동형 AI 챗봇 에이전트**를 구축합니다. 
기존의 정적인 텍스트 박스 형태의 인사이트 제공을 넘어, 유저가 직접 질문하고 AI가 대답할 수 있는 플로팅 챗봇(Floating Chat Widget) 형태로 구현합니다.

## User Review Required

> [!IMPORTANT]
> 로컬 AI 모델(LM Studio)을 사용 중이시므로, 챗봇의 응답 속도는 로컬 PC의 성능(GPU 등)에 영향을 받습니다. 
> 또한, 첫 번째 버전에서는 **"환자의 데이터를 읽고 대답해 주는 대화형 상담 기능"**에 집중하고, 유저를 대신해 수동 기록을 입력해 주는 자동화 도구(Function Calling)는 이번 버전이 안정화된 이후(Phase 2)에 도입하는 것이 안전합니다. 이에 동의하시는지 확인 부탁드립니다.

## Open Questions

> [!NOTE]
> 1. AI 챗봇의 프로필 이름(예: "Healus AI 주치의", "Dr. Healus")을 정해주실 수 있을까요? 기본값으로 "Dr. Healus"를 사용하겠습니다.
> 2. 챗봇을 대시보드 우측 하단에 동그란 말풍선 버튼(플로팅 아이콘)으로 띄우는 형태가 마음에 드시나요?

---

## Proposed Changes

### 백엔드 (Backend - FastAPI)

#### [MODIFY] [web.py](file:///E:/projects/healus-backend/api/web.py)
- **새로운 엔드포인트 추가:** `POST /api/chat`
- **로직 구현:** 
  - 프론트엔드로부터 유저의 질문과 이전 대화 내역(`messages` 배열)을 전달받습니다.
  - DB에서 유저의 최근 7일치 혈당 및 펌프 로그를 조회하여 AI가 참고할 수 있도록 **시스템 프롬프트(System Prompt)**의 컨텍스트로 몰래 주입합니다.
  - LM Studio(Llama 3.1) 모델에 전체 대화 컨텍스트를 전송하고, 반환된 AI의 답변을 프론트엔드로 전달합니다.

#### [MODIFY] [schemas.py](file:///E:/projects/healus-backend/models/schemas.py)
- **스키마 추가:** 프론트엔드에서 넘어오는 채팅 메시지 형식을 정의하는 `ChatMessage` 및 `ChatRequest` Pydantic 모델을 추가합니다.

---

### 프론트엔드 (Frontend - React)

#### [NEW] [AIChatWidget.tsx](file:///E:/projects/healus-web/src/components/AIChatWidget.tsx)
- 화면 우측 하단에 항상 떠 있는 **플로팅 챗봇 위젯 컴포넌트**를 신규 생성합니다.
- 말풍선 아이콘을 클릭하면 채팅창이 위로 팝업되며 펼쳐집니다.
- 유저의 입력, AI의 응답, 로딩 상태(Loading Spinner)를 관리하는 UI 로직을 포함합니다.
- `axios`를 통해 백엔드의 `/api/chat` API와 통신합니다.

#### [MODIFY] [Dashboard.tsx](file:///E:/projects/healus-web/src/pages/Dashboard.tsx)
- 만들어진 `AIChatWidget` 컴포넌트를 대시보드 페이지에 Import 하여 렌더링합니다.

---

## Verification Plan

### 수동 검증 (Manual Verification)
1. **웹 대시보드 확인:** http://localhost:5173/dashboard 에 진입했을 때 우측 하단에 챗봇 아이콘이 예쁘게 나타나는지 확인.
2. **채팅 테스트:** 챗봇을 열고 *"내 최근 혈당 수치가 어때?"* 또는 *"어제 수면시간이 부족했는데 혈당에 영향이 있을까?"* 라고 질문해 봅니다.
3. **데이터 연동 확인:** AI가 단순히 일반적인 대답을 하는 것이 아니라, **실제 대시보드에 있는 데이터(어제 수면 시간, 최근 주입량 등)를 바탕으로** 구체적이고 개인화된 조언을 해주는지 검증합니다.
