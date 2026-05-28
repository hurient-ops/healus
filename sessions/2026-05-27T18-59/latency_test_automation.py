import time
import requests
import json
from datetime import datetime

# --- Configuration ---
API_ENDPOINT = "http://ble_service:8080/latency_check"  # BLE 서비스의 예상 엔드포인트 (가정)
TEST_DURATION_SECONDS = 3600  # 테스트 시간 (1시간)
TEST_INTERVAL = 5  # 측정 간격 (초)
NUM_ITERATIONS = 100 # 반복 횟수

def measure_latency(endpoint: str) -> float:
    """특정 엔드포인트에 대한 요청 지연 시간을 측정합니다."""
    start_time = time.time()
    try:
        # 실제 BLE 시스템과의 통신을 가정하고 POST 요청을 보냅니다.
        payload = {"type": "latency_request", "timestamp": str(datetime.now())}
        response = requests.post(endpoint, json=payload, timeout=10)
        response.raise_for_status()  # HTTP 오류 발생 시 예외 발생
        end_time = time.time()
        latency = (end_time - start_time) * 1000  # 밀리초로 변환
        return latency
    except requests.exceptions.RequestException as e:
        print(f"Error during API request to {endpoint}: {e}")
        return -1.0 # 실패 시 -1 반환

def run_load_test_scenario(duration: int, interval: int, iterations: int):
    """지정된 시간 동안 반복적으로 Latency를 측정하는 부하 테스트 시나리오입니다."""
    print(f"🚀 Latency Load Test 시작. 목표 시간: {duration}초, 간격: {interval}초, 반복 횟수: {iterations}")
    start_time = time.time()
    all_latencies = []

    while (time.time() - start_time) < duration:
        print(f"\n--- 측정 시작 ({datetime.now().strftime('%H:%M:%S')}) ---")
        current_latencies = []
        for i in range(iterations):
            latency = measure_latency(API_ENDPOINT)
            if latency >= 0:
                current_latencies.append(latency)

        if current_latencies:
            avg_latency = sum(current_latencies) / len(current_latencies)
            print(f"측정 완료. {len(current_latencies)}회 측정 평균 지연 시간: {avg_latency:.2f} ms")
            all_latencies.extend(current_latencies)
        else:
            print("⚠️ 측정 실패 또는 응답 없음. 다음 사이클 대기.")

        # 다음 측정을 위해 잠시 대기 (실제 환경에서는 이 타이밍을 조절해야 함)
        time.sleep(interval)

    end_time = time.time()
    total_duration = end_time - start_time
    print("\n=============================================")
    print("✅ Latency Load Test 완료")
    print(f"총 실행 시간: {total_duration:.2f} 초")
    if all_latencies:
        print(f"모든 측정 결과 평균 지연 시간: {sum(all_latencies) / len(all_latencies):.2f} ms")
    else:
        print("측정된 데이터가 없습니다.")
    print("=============================================")

if __name__ == "__main__":
    print("--- Latency Verification Script Initialized ---")
    run_load_test_scenario(TEST_DURATION_SECONDS, TEST_INTERVAL, NUM_ITERATIONS)