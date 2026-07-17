import json
import pandas as pd
from datetime import datetime

def load_data(file_path: str) -> dict:
    """JSON 파일을 로드합니다."""
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        print(f"✅ 데이터 로드 성공: {file_path}")
        return data
    except FileNotFoundError:
        print(f"❌ 에러: 파일을 찾을 수 없습니다. 경로를 확인하세요: {file_path}")
        return None
    except json.JSONDecodeError:
        print(f"❌ 에러: JSON 디코딩 오류가 발생했습니다: {file_path}")
        return None

def define_thresholds(data: dict, security_targets: dict, latency_targets: dict) -> dict:
    """보안 및 Latency 기준을 정의하고 데이터에 적용합니다."""
    analysis = {}
    
    # 보안 분석 ($X_{security}$)
    sec_results = data.get('security_metrics', {})
    for metric, target in security_targets.items():
        actual = sec_results.get(metric)
        if actual is not None:
            deviation = "PASS" if actual <= target else "FAIL"
            analysis[f"Security_{metric}"] = {
                "Actual": actual,
                "Target": target,
                "Deviation": deviation,
                "RCA_Hint": "규제/보안 준수 여부 확인 필요." if deviation == "FAIL" else "기준 준수됨."
            }

    # Latency 분석 (L)
    latency_results = data.get('latency_metrics', {})
    for metric, target in latency_targets.items():
        actual = latency_results.get(metric)
        if actual is not None:
            deviation = "PASS" if actual <= target else "FAIL"
            analysis[f"Latency_{metric}"] = {
                "Actual": actual,
                "Target": target,
                "Deviation": deviation,
                "RCA_Hint": "응답 시간 지연 원인(DB 쿼리, 외부 API 호출 등) 분석 필요." if deviation == "FAIL" else "기준 충족됨."
            }
            
    return analysis

def generate_rca_report(analysis_results: dict, source_file: str, context: dict) -> str:
    """분석 결과를 기반으로 RCA 보고서를 생성합니다."""
    report = [f"=======================================================",
              f"📊 Root Cause Analysis (RCA) Report",
              f"Source File: {source_file}",
              f"Generated At: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
              f"=======================================================\n"]

    report.append("--- 1. 요약 및 핵심 지표 ---")
    total_failures = sum(1 for res in analysis_results.values() if res.get('Deviation') == 'FAIL')
    report.append(f"총 실패 지점 수: {total_failures} / {len(analysis_results)}")

    report.append("\n--- 2. 상세 분석 결과 ---")
    for key, result in analysis_results.items():
        report.append(f"\n[{key}]")
        report.append(f"  > 실제 값: {result['Actual']}, 목표치: {result['Target']}")
        report.append(f"  > 상태: {result['Deviation']}")
        report.append(f"  > RCA 힌트: {result['RCA_Hint']}")

    report.append("\n--- 3. 자동화된 원인 추론 프레임워크 ---")
    report.append("💡 다음 단계: 실제 Fail 항목에 대해 'RCA_Hint'를 기반으로 시스템 로그 및 코드 리뷰를 수행하세요.")
    report.append("🔑 핵심 조치 사항: 실패 지점의 `RCA_Hint`를 참조하여, 관련 모듈(BLE 통신, 데이터베이스 쿼리, 인증 로직 등)의 코드를 즉시 검토하고 Hotfix를 적용해야 합니다.")

    return "\n".join(report)

def run_rca_pipeline(data_path: str, security_config: dict, latency_config: dict):
    """RCA 파이프라인 전체 실행 함수."""
    print("🚀 RCA 파이프라인 시작...")
    
    # 1. 데이터 로드
    raw_data = load_data(data_path)
    if not raw_data:
        return

    # 2. 기준 정의 및 분석
    analysis = define_thresholds(raw_data, security_config, latency_config)
    
    # 3. 보고서 생성
    report = generate_rca_report(analysis, data_path, {"Security": security_config, "Latency": latency_config})
    
    print("\n=======================================================")
    print("✨ 최종 RCA 보고서 ✨")
    print("=======================================================")
    print(report)
    print("\n🚀 RCA 파이프라인 완료.")

# --- 실행 예시 (사용자가 test_results.json을 제공할 때 이 함수를 호출) ---
if __name__ == "__main__":
    # 실제 데이터 경로와 설정은 사용자가 제공해야 함. 
    # 여기서는 임의의 설정을 사용하여 구조만 확인합니다.
    DATA_FILE = "test_results.json"
    SECURITY_CONFIG = {
        "$X_{security}": 10,  # 예시: 보안 지표 목표치
        "P0_vulnerabilities": 0
    }
    LATENCY_CONFIG = {
        "Avg_Response_Time_ms": 500, # 예시: Latency 목표치
        "Max_Latency_ms": 1000
    }
    
    # 실제 실행을 위해서는 test_results.json 파일이 필요합니다.
    # run_rca_pipeline(DATA_FILE, SECURITY_CONFIG, LATENCY_CONFIG)
    print("\n📝 프레임워크 준비 완료. 실제 데이터(`test_results.json`)를 제공하면 즉시 분석을 실행하겠습니다.")