// P0: BLE 통신 보안 모듈 (AES-GCM 기반)
import * as crypto from 'crypto';

/**
 * AES-GCM을 사용하여 데이터를 암호화하고 복호화하는 유틸리티
 * @param data 암호화할 데이터 (Buffer 형태)
 * @param key 암호화 키 (Buffer 형태)
 * @param iv 초기화 벡터 (Buffer 형태)
 * @returns 암호화된 데이터와 인증 태그
 */
export function encryptData(data: Buffer, key: Buffer, iv: Buffer): { ciphertext: Buffer, tag: Buffer } {
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    let encrypted = cipher.update(data);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    const tag = cipher.getAuthTag();
    return { ciphertext: encrypted, tag: tag };
}

/**
 * 암호화된 데이터를 복호화하고 인증 태그를 검증하는 함수
 * @param ciphertext 암호화된 데이터 (Buffer 형태)
 * @param key 암호화 키 (Buffer 형태)
 * @param iv 초기화 벡터 (Buffer 형태)
 * @param tag 인증 태그 (Buffer 형태)
 * @returns 복호화된 데이터 (Buffer 형태) 또는 에러
 */
export function decryptData(ciphertext: Buffer, key: Buffer, iv: Buffer, tag: Buffer): Buffer {
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    let decrypted = decipher.update(ciphertext);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return decrypted;
}

// 예시: 키와 IV는 실제 환경에서 안전하게 관리되어야 함 (환경변수 또는 키 관리 서비스 사용)
// const KEY = Buffer.from('a_very_secure_32_byte_key', 'utf8'); // 32 bytes for AES-256
// const IV = Buffer.from('initial_iv', 'utf8'); // 12 bytes for GCM IV
// const DATA = Buffer.from('sensitive_ble_data');
// const { ciphertext, tag } = encryptData(DATA, KEY, IV);
// console.log("Encrypted:", ciphertext.toString('hex'));
// console.log("Tag:", tag.toString('hex'));
// const decrypted = decryptData(ciphertext, KEY, IV, tag);
// console.log("Decrypted:", decrypted.toString('utf8'));

export { encryptData, decryptData };