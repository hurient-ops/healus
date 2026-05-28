# 디자인 및 안정성 통합 명세서 (Visual & Functional Alignment Specification)

## 🛡️ 디자인 및 안정성 통합 명세서 (Visual & Functional Alignment Specification)

### 1. 핵심 컬러 시스템: 위험 회피 심리 극대화 (Risk Aversion Psychology)

핵심 색상인 **골드(Gold)**와 **딥티알(Deep Teal)**을 기반으로, $X_{security}$ 레벨에 따라 보조 색상을 동적으로 변화시켜 사용자의 위험 회피 심리를 시각적으로 반영합니다.

| 안정성 레벨 ($X_{security}$) | 디자인 상태 명칭 (State Name) | 메인 컬러 팔레트 (Primary Palette) | 강조/경고 컬러 (Accent/Alert Color) | 심리적 효과 |
| :--- | :--- | :--- | :--- | :--- |
| **Level 1: Safe** (매우 안정) | Assurance Mode | Deep Teal (주요 배경) / Gold (강조) | Light Green (안정 표시) | 신뢰, 평온함 |
| **Level 2: Caution** (주의 필요) | Warning Mode | Deep Teal (배경) / Amber (경고) | Yellow/Orange (주의 알림) | 경계, 주의 환기 |
| **Level 3: High Risk** (위험 구간) | Alert Mode | Dark Gray/Black (배경) / Gold (경고 강조) | Red (즉각적인 위험 알림) | 긴급성, 즉각적 조치 요구 |

### 2. 안정성 레벨 바 (Stability Level Bar) 컴포넌트 정의

모든 화면에서 기술 안정성 상태를 직관적으로 보여주는 시각적 요소로, 사용자가 현재 시스템의 신뢰도를 즉시 파악할 수 있도록 설계합니다.

*   **구성:** 가로형 진행 막대(Progress Bar) 형태를 채택합니다.
*   **동적 변화:** 막대의 **채움 색상**은 위 1번에서 정의된 컬러 시스템에 따라 결정됩니다 (Safe $\rightarrow$ Caution $\rightarrow$ Alert).
*   **텍스트 레이블:** 막대 아래에는 현재 안정성 레벨($X_{security}$ 값)과 상태 명칭(Assurance Mode, Warning Mode 등)을 명확히 표시합니다.

### 3. 통합 검증 기준 (Integrated Verification Criteria)

디자인 결과물과 개발 로직 간의 **시각적 일치성**을 측정하기 위한 병렬 검증 기준을 명시합니다.

| 검증 항목 | 담당 에이전트 | 측정 목표 | 연계 지표 ($X_{security}$와의 관계) |
| :--- | :--- | :--- | :--- |
| **컬러 매핑 정확도** | 🎨 Designer / 💻 코다리 | 디자인 시스템의 색상 토큰과 실제 코드 내 상태 변수 값($X_{security}$)이 일치하는지 확인. | $\text{Color}_{\text{Design}} \leftrightarrow \text{State}_{\text{Code}}$ 일치율 ($\ge 95\%$) |
| **위험 시각화 일치성** | 🎨 Designer / 💻 코다리 | 위험 알림 상태(Alert Mode)가 UI에서 명확히 전달되는지, 그리고 코드상에서 해당 경고 조건이 정확하게 트리거되었는지 확인. | $\text{Risk}_{\text{Code}} \rightarrow \text{Visual}_{\text{UI}}$ 반응 속도 ($\le 100ms$) |
| **TCM 연계 검증** | 💼 현빈 / 📱 영숙 | TCM 프레임워크에 입력된 개발 마일스톤과 디자인의 진행 상태가 시간적으로 동기화되는지 확인. | $\text{Timeline}_{\text{Code}} \leftrightarrow \text{Progress}_{\text{Design}}$ 일치율 ($\ge 90\%$) |