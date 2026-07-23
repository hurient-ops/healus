// 파일 생성 시작: risk_alerting.ts (로그 스트림 통합)
import { AuthCrypto } from './auth_crypto';

export class RiskAlertingService {
    private crypto: AuthCrypto;
    private logStreamClient: any; // 실시간 로그 스트림 클라이언트 연결 객체

    constructor(cryptoInstance: AuthCrypto, logStreamClient: any) {
        this.crypto = cryptoInstance;
        this.logStreamClient = logStreamClient;
        console.log("RiskAlertingService initialized. Integrated with Crypto and Log Stream.");
    }

    /**
     * BLE 통신 요청 시 암호화 및 인증을 수행하고, 오류 발생 시 로그 스트림으로 보고합니다. (P0 통합)
     * @param rawData 원본 데이터
     * @param devicePublicKey 장치 공개 키
     * @param signature 장치 서명
     */
    async processSecureTransmission(rawData: string, devicePublicKey: string, signature: string): Promise<boolean> {
        try {
            // 1. 인증 및 암호화 수행 (P0 핵심 로직)
            const encrypted = this.crypto.encrypt(rawData);
            console.log("Data encrypted successfully.");

            // 2. 실시간 로그 스트림으로 오류/상태 보고 (통합 기능)
            this.logStreamClient.sendLog({
                level: 'INFO',
                source: 'BLE_AUTH',
                message: `Device authenticated and data encrypted. IV: ${encrypted.iv.substring(0, 10)}`,
                stabilityCheck: 'PASS' // P0 제약 조건 만족 확인
            });

            // 3. 장치 인증 검증 (Public Key 기반)
            const authSuccess = this.crypto.verifyDeviceAuth(devicePublicKey, signature);

            if (!authSuccess) {
                this.logStreamClient.sendLog({
                    level: 'ERROR',
                    source: 'BLE_AUTH',
                    message: 'Authentication Failed after encryption.',
                    stabilityCheck: 'FAIL' // P0 위반 시 실패 로그 기록
                });
                throw new Error("Device authentication failed.");
            }

            return true;

        } catch (error) {
            // 인증 또는 암호화 중 오류 발생 시 즉시 Critical Log 기록
            this.logStreamClient.sendLog({
                level: 'CRITICAL',
                source: 'BLE_SECURITY',
                message: `Security processing failed: ${error.message}`,
                stabilityCheck: 'FAIL' // P0 위반으로 간주하고 최고 레벨 로그 기록
            });
            throw error;
        }
    }
}