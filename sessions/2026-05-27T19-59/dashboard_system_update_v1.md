# 🛡️ 디자인 시스템 업데이트: ROI 대시보드 통합 가이드 (컨셉 1)

## 1. 브랜드 스타일 확정 (Color & Typography)

*   **Primary Color (신뢰/프리미엄):** Gold (#FFD700)
    *   `HEX`: #FFD700
    *   `RGB`: 255, 215, 0
    *   `Usage`: 핵심 CTA, 강조 지표(ROI 수치), 방패의 테두리.
*   **Secondary Color (안정성/기술):** Deep Teal (#008080)
    *   `HEX`: #008080
    *   `RGB`: 0, 128, 128
    *   `Usage`: 배경 영역, 보조 지표, 데이터 그래프의 주 색상.
*   **Typography:** Inter (모든 UI 요소에 일관성 유지)

## 2. 대시보드 레이아웃 정의: The Shield of Assurance

**목표:** 모든 ROI 지표가 '안전성'이라는 중앙 테마 아래 보호받고 있음을 시각화.

*   **Layout Type:** Centered, Layered Card Structure
*   **Container:** 전체 화면을 깊은 회색 배경(#333333)으로 설정하여 Gold와 Teal이 돋보이게 함.
*   **Central Element (The Shield):** 대시보드의 중앙에 크고 입체적인 '방패' 형태의 레이어를 배치. 이 방패는 데이터 영역을 감싸는 프레임 역할을 수행함.

## 3. 핵심 컴포넌트 명세

### A. ROI 지표 카드 (ROI Metrics Card)
*   **스타일:** Deep Teal 배경, Gold 테두리.
*   **내용 구성:** 각 카드(예: 보안 ROI, Latency ROI, 비용 절감 ROI)는 독립된 '보호 영역'으로 간주하며, 내부에는 해당 지표와 목표 대비 달성률을 명확히 표시합니다.

### B. 기술 안정성 인디케이터 (Stability Indicator)
*   **위치:** 대시보드 상단 중앙 또는 방패의 최상단 위치.
*   **구성:** $X_{security}$ 및 Latency 수치를 별도의 게이지/바 형태로 시각화하여, **'안정성의 현재 상태'**를 즉각적으로 파악할 수 있도록 함. (예: 보안 지표는 녹색(Safe), 노란색(Monitor), 빨간색(Risk)으로 색상 코딩).

### C. 데이터 시각화 (Graph Integration)
*   모든 추세 데이터 그래프는 Deep Teal을 주 색상으로 사용하며, Gold로 주요 벤치마크 라인을 표시하여 **'목표 달성 경로'**를 명확히 제시합니다.

## 4. 최종 통합 지침

이 가이드라인은 향후 모든 디자인 및 개발 작업의 기준이 됩니다. 디자인 시스템의 모든 컴포넌트는 이 'Shield' 메타포와 골드/딥티알 색상 조합을 따르며, 데이터는 **'위험 회피 투자 관점'**에서 해석되어야 합니다.