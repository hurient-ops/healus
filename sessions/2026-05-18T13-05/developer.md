<find># risk_alerting.ts</find><replace>// --- risk_alerting.ts (Risk Alerting Module) ---
import { AuthCrypto } from './auth_crypto'; // 의존성 설정

/**
 * P0: 위험 구간 알림 및 상태 모니터링 모듈
 */

export class RiskAlerting {
    private cryptoService: AuthCrypto;

    constructor(cryptoService: AuthCrypto) {
        this.cryptoService = cryptoService;
        console.log("RiskAlerting initialized, linked to Crypto Service.");
    }

    /**
     * 위험 구간 감지 및 알림 로직 실행 (P0: 위험 알림)
     * @param sensorData 센서로부터 받은 데이터
     * @returns 알림 상태 (보안 상태 포함)
     */
    checkRiskAndAlert(sensorData: any): { status: string, securityCheck: boolean, alertMessage: string } {
        const encryptedPayload = this.cryptoService.encrypt(JSON.stringify(sensorData));
        let securityStatus = false;
        let alertMessage = "Normal operation.";

        // 1. 데이터 무결성 검증 (P0)
        if (this.cryptoService.verify(encryptedPayload, 'risk_tag_placeholder')) {
            securityStatus = true; // 암호화된 데이터의 유효성 확인 성공
            alertMessage = "Data integrity verified.";
        } else {
            alertMessage = "CRITICAL: Data integrity failure detected!";
        }

        // 2. 위험 임계값 체크 (P1 연계 준비)
        if (sensorData.value > 350) { // 예시 임계값
            securityStatus = false;
            alertMessage = `HIGH RISK ALERT: Value ${sensorData.value} exceeds safety threshold.`;
        }

        return { status: securityStatus ? "SECURE" : "RISKY", securityCheck: securityStatus, alertMessage: alertMessage };
    }
}