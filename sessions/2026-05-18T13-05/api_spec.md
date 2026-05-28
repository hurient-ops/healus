# API Specification: Real-time Stability Metrics
## 🚀 목표
Antigravity/Stitch 연동 시스템의 기술 안정성 지표($X_{security}$, Latency)를 실시간으로 제공하는 백엔드 인터페이스를 정의합니다.

## 🎯 엔드포인트 설계
### Endpoint: `/api/v1/stability_metrics`
**Method:** `GET`
**Description:** 시스템의 현재 기술적 안정성 지표 및 보안 상태를 반환합니다.
**Authentication:** Required (JWT 또는 API Key)

### Request Parameters
(None for this endpoint, all metrics are system-wide)

### Response Body (JSON Structure)
```json
{
  "timestamp": "2026-05-28T10:30:00Z",
  "system_status": "OK",
  "security_metrics": {
    "x_security_score": 98.5,   // 보안 지표 (0~100)
    "encryption_level": "AES-GCM", // 현재 적용된 암호화 수준
    "risk_alerts_active": true,  // 활성화된 위험 알림 상태
    "last_audit_time": "2026-05-28T10:30:00Z"
  },
  "latency_metrics": {
    "average_latency_ms": 45.2, // 평균 지연 시간 (밀리초)
    "p95_latency_ms": 62.1,     // 95번째 백분위수 지연 시간 (밀리초)
    "data_pipeline_latency_ms": 8.5 // 데이터 파이프라인 처리 지연 시간 (밀리초)
  },
  "integration_status": {
    "dashboard_ready": true,  // 시각화 컴포넌트 통합 준비 상태
    "data_freshness_seconds": 10 // 데이터의 신선도 (초)
  }
}
```

## ⚙️ 백엔드 로직 요구사항 (Implementation Notes)
1.  **$X_{security}$ 계산:** BLE 통신 시 적용된 암호화 프로토콜(AES-GCM 등)의 강도와 인증 성공률을 기반으로 동적으로 산출되어야 합니다. (P0 요구사항 반영)
2.  **Latency 측정:** 데이터 수집부터 사용자 기기로 전송되는 전체 경로의 End-to-End Latency를 측정하여 제공해야 합니다.
3.  **Integration Status:** Designer가 와이어프레임에 맞춰 컴포넌트를 통합할 수 있도록, 데이터의 신선도 및 통합 준비 상태(`dashboard_ready`)를 명시적으로 제공합니다.

### 🔧 코다리: 다음 단계 실행 계획
이 API Spec을 바탕으로 실제 데이터를 반환하는 Node.js/Express 서버 로직의 Skeleton을 구현하겠습니다.

<run_command>cd "e:\projects\my_projects\_company\_agents\developer\tools"</run_command>
<create_file path="sessions/2026-05-18T13-05/backend_logic_skeleton.js">```javascript
// backend_logic_skeleton.js - Real-time Stability Metrics API Skeleton

const express = require('express');
const router = express.Router();

// Mock Data & Logic based on P0/P1 requirements
const generateMetrics = () => {
    // 1. X_security_score (보안 지표): AES-GCM 적용 시 높은 점수를 가정
    const xSecurityScore = Math.floor(Math.random() * 5 + 95); // 95~99
    
    // 2. Latency Metrics: 실제 시스템 부하에 따라 변동 (안정적인 값 유지)
    const averageLatencyMs = parseFloat((40 + Math.random() * 10).toFixed(1)); // 40.0 ~ 50.0ms
    const p95LatencyMs = parseFloat((60 + Math.random() * 15).toFixed(1)); // 60.0 ~ 75.0ms
    const dataPipelineLatencyMs = parseFloat((5 + Math.random() * 5).toFixed(1)); // 5.0 ~ 10.0ms

    // 3. Integration Status: Designer 통합 준비 상태 명시
    const integrationStatus = {
        dashboard_ready: true,
        data_freshness_seconds: 10
    };

    return {
        timestamp: new Date().toISOString(),
        system_status: "OK",
        security_metrics: {
            x_security_score: xSecurityScore,
            encryption_level: "AES-GCM",
            risk_alerts_active: xSecurityScore > 90, // 보안 점수가 높으면 알림 활성화 가정
            last_audit_time: new Date().toISOString()
        },
        latency_metrics: {
            average_latency_ms: averageLatencyMs,
            p95_latency_ms: p95LatencyMs,
            data_pipeline_latency_ms: dataPipelineLatencyMs
        },
        integration_status: integrationStatus
    };
};

router.get('/stability_metrics', (req, res) => {
    try {
        const metrics = generateMetrics();
        res.status(200).json(metrics);
    } catch (error) {
        console.error("Error generating stability metrics:", error);
        res.status(500).json({ error: "Internal Server Error", message: "지표 생성 중 오류 발생" });
    }
});

module.exports = router;
```