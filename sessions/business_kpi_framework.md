# KPI 프레임워크: CSI 기반 수익화 모델
## 1. 핵심 지표 정의
- $P_0$: 시스템 안정성 (오류 로그 기반)
- $Latency$: 평균 지연 시간 (플로우 기반)
- $PES$: 프리미엄 경험 점수
- $ARPU$: 사용자당 평균 수익

## 2. Critical Stability Index (CSI) 공식
$$ \text{CSI} = w_1 \cdot (1 - P_0) + w_2 \cdot (\frac{Latency}{\text{Target\_Latency}}) $$
(여기서 $w_1=0.6$, $w_2=0.4$로 초기 설정)

## 3. 영향 관계 모델
- $PES = g(\text{CSI}) \times \text{Base\_Value}$
- $ARPU = \text{Base\_ARPU} \times h(PES)$

## 4. 실행 권고
1. 개발팀: CSI 계산 로직을 WebSocket 스트림에 통합하여 실시간으로 노출하는 API 설계.
2. Business: Gold Tier 플로우의 각 단계별 $\text{CSI}$ 임계값 설정 및 우선순위 확정.