// 위험 구간 알림 로직 모듈
import { encryptData, decryptData } from './auth_crypto';

/**
 * BLE 통신 데이터에서 위험 신호를 감지하고 알림을 생성하는 함수
 * @param rawBleData 수신된 원시 BLE 데이터 스트림
 * @param key 암호화 키
 * @param iv 초기화 벡터
 * @returns 위험 알림 객체 또는 null
 */
export function analyzeRiskAlert(rawBleData: Buffer, key: Buffer, iv: Buffer): { riskLevel: 'LOW' | 'MEDIUM' | 'HIGH', message: string } | null {
    // 실제 구현에서는 복호화된 데이터를 분석하여 위험 임계값을 체크해야 함.
    // 여기서는 시뮬레이션 로직만 구현합니다.
    const decryptedData = decryptData(rawBleData, key, iv, Buffer.from('dummy_tag')); // 태그는 실제로는 받아와야 함

    if (decryptedData.toString().includes("CRITICAL_THRESHOLD")) {
        return { riskLevel: 'HIGH', message: "Critical Threshold Violation Detected." };
    } else if (decryptedData.toString().includes("WARNING_THRESHOLD")) {
        return { riskLevel: 'MEDIUM', message: "Warning Threshold Reached." };
    }

    return null;
}

export { analyzeRiskAlert };