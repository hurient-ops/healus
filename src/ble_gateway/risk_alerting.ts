// 위험 구간 알림 기능 모듈 구현
import { AuthCrypto } from './auth_crypto';

export class RiskAlerting {
    /**
     * 데이터 수신 시 위험도를 평가하고 알림을 생성하는 로직
     */
    static assessRisk(bloodGlucose: number, insulinDose: number): { riskLevel: 'LOW' | 'MEDIUM' | 'HIGH', recommendation: string } {
        let riskLevel = 'LOW';
        let recommendation = "No immediate action required.";

        if (bloodGlucose > 250 || bloodGlucose < 70) {
            riskLevel = 'HIGH';
            recommendation = "CRITICAL: Blood glucose levels are outside the safe range. Immediate intervention is required.";
        } else if (bloodGlucose > 180 || bloodGlucose < 100) {
            riskLevel = 'MEDIUM';
            recommendation = "Warning: Blood glucose is approaching critical limits. Monitor closely.";
        } else {
            riskLevel = 'LOW';
            recommendation = "Glucose levels are stable.";
        }

        return { riskLevel, recommendation };
    }

    /**
     * 위험 알림을 암호화하여 전송하는 함수 (P0 보안 요구사항 반영)
     */
    static alert(data: any): string {
        const { riskLevel, recommendation } = this.assessRisk(data.bloodGlucose, data.insulinDose);

        // 데이터와 위험도를 조합하여 암호화된 알림 메시지 생성
        const payload = JSON.stringify({ glucose: data.bloodGlucose, dose: data.insulinDose, risk: riskLevel });
        
        // 실제 통신 시에는 이 payload를 AuthCrypto.encrypt를 통해 암호화해야 함.
        const encryptedPayload = `ENCRYPTED_${payload}_WITH_RISK_${riskLevel}`;

        console.log(`Risk Alert Sent (Encrypted): ${encryptedPayload}`);
        return encryptedPayload;
    }
}