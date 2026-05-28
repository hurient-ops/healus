import { encryptData, decryptData, manageDynamicKeys } from './auth_crypto';

/**
 * 위험 구간 알림 모듈 (P0)
 * BLE 통신 및 데이터 무결성 위반 시 경고를 발생시킵니다.
 */

export function checkRiskAlert(deviceId: string, receivedData: Buffer, expectedNonce: string, receivedTag: Buffer): { status: 'OK' | 'ERROR', message: string } {
    const key = crypto.randomBytes(32); // 실제 환경에서는 키를 안전하게 관리해야 함

    try {
        // 1. 데이터 복호화 및 인증 확인 (AES-GCM 검증)
        const decryptedData = decryptData(receivedData, key, Buffer.from(expectedNonce, 'hex'), receivedTag);

        // 2. 위험 알림 로직 (예시: Nonce 불일치 또는 데이터 무결성 실패 시)
        if (decryptedData.toString('utf8').length === 0) {
             return { status: 'ERROR', message: '데이터 내용이 비어있습니다. 데이터 손상 의심.' };
        }

        // TODO: 실제 위험 판단 로직(예: 예측 모델 연계) 추가 필요
        if (receivedTag.toString('hex') !== Buffer.from(expectedNonce, 'hex').slice(0, 32).toString('hex')) {
            return { status: 'ERROR', message: '인증 태그 불일치! 데이터 무결성 위반 ($X_{security}$ 경고)' };
        }

        return { status: 'OK', message: `데이터 수신 및 인증 성공. (길이: ${decryptedData.length})` };

    } catch (e) {
        // 복호화 실패 또는 기타 오류 발생 시 즉시 에러 반환
        return { status: 'ERROR', message: `보안 모듈 오류: ${e.message}` };
    }
}

/**
 * BLE 통신 위험 알림을 위한 데이터 패킷 생성 함수 (API 설계 초안)
 */
export function createRiskPacket(deviceId: string, payload: string, nonce: string): { data: Buffer, nonce_hex: string, tag_hex: string } {
    const key = crypto.randomBytes(32); // 실제 환경에서는 키를 안전하게 관리해야 함

    const iv = crypto.randomBytes(12); // 새로운 IV 생성 (보안 강화)
    const plaintext = Buffer.from(payload, 'utf8');

    // 암호화 실행
    const { ciphertext, tag } = encryptData(plaintext, key, iv);

    return {
        data: ciphertext,
        nonce_hex: nonce, // 통신 세션에 사용될 Nonce
        tag_hex: tag.toString('hex') // 인증 태그
    };
}