# developer_metrics_api.py
import time
import random
from typing import Dict, Any

# --- Configuration ---
MIN_SECURITY_LEVEL = 95.0  # X_security minimum threshold
MAX_LATENCY_MS = 50       # Latency maximum threshold

def generate_mock_metrics() -> Dict[str, Any]:
    """
    실시간으로 모의 데이터를 생성하여 API 응답을 준비합니다.
    실제 환경에서는 이 부분이 BLE 통신 결과 및 시스템 상태와 연동되어야 합니다.
    """
    # 1. 보안 지표 (X_security): 95% 이상 유지 목표
    x_security = round(random.uniform(95.0, 100.0), 2)

    # 2. 지연 시간 (Latency): 50ms 이하 유지 목표
    latency_ms = round(random.uniform(10.0, 45.0), 2) # 50ms 미만으로 설정하여 안정성 확보 시뮬레이션

    # 최종 검증 로직 (시스템 요구사항 반영)
    is_secure = x_security >= MIN_SECURITY_LEVEL
    is_fast = latency_ms <= MAX_LATENCY_MS

    status = "PASS" if is_secure and is_fast else "FAIL"

    return {
        "timestamp": int(time.time()),
        "metrics": {
            "x_security": x_security,  # 보안 안정성 지표 (0~100)
            "latency_ms": latency_ms, # 응답 지연 시간 (ms)
        },
        "status": status,
        "thresholds": {
            "min_security": MIN_SECURITY_LEVEL,
            "max_latency": MAX_LATENCY_MS
        }
    }

def get_metrics() -> Dict[str, Any]:
    """API 엔드포인트 역할을 수행하는 함수"""
    data = generate_mock_metrics()
    return data

# --- Simulation / Testing for immediate feedback ---
if __name__ == "__main__":
    print("--- Mock Metrics Test ---")
    for _ in range(5):
        result = get_metrics()
        print(f"Time: {result['timestamp']}, Status: {result['status']}")
        print(f"Security: {result['metrics']['x_security']}%, Latency: {result['metrics']['latency_ms']}ms")
    print("------------------------")