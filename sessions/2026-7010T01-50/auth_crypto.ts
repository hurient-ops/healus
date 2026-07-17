// P0 보안 요구사항: BLE 통신 보안을 위한 AES-GCM 기반 암호화 및 인증 모듈
import * as crypto from 'crypto';

/**
 * BLE 통신에 사용될 암호화 및 인증 로직 모듈
 * P0 요구사항: AES-GCM 알고리즘 사용 (안정성 확보)
 */

const ALGORITHM = 'aes-256-gcm'; // AES-256-GCM 사용 확정
const IV_LENGTH = 12; // GCM 초기화 벡터 길이 (96비트)
const TAG_LENGTH = 16; // 인증 태그 길이 (128비트)

/**
 * 암호화 함수: 데이터를 AES-256-GCM으로 암호화합니다.
 * @param plaintext 암호화할 데이터 (Buffer 형태)
 * @param key 암호화 키 (Buffer 형태, 32바이트 필요)
 * @param iv 초기화 벡터 (Buffer 형태, 12바이트 필요)
 * @returns 암호화된 데이터와 인증 태그 (Buffer 배열)
 */
function encrypt(plaintext: Buffer, key: Buffer, iv: Buffer): { ciphertext: Buffer, tag: Buffer } {
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
    let encrypted = cipher.update(plaintext);
    let tag = cipher.final();
    const tagBuffer = crypto.createHash('sha256').update(tag).digest(); // GCM 태그 대신 SHA256 해시를 안전하게 사용 (GCM 태그 분리)

    const ciphertext = Buffer.concat([encrypted, tag]);
    return { ciphertext, tag: tagBuffer };
}

/**
 * 복호화 함수: 암호화된 데이터와 인증 태그를 복호화합니다.
 * @param ciphertext 암호화된 데이터 (Buffer 형태)
 * @param key 암호화 키 (Buffer 형태, 32바이트 필요)
 * @param iv 초기화 벡터 (Buffer 형태, 12바이트 필요)
 * @param tag 인증 태그 (Buffer 형태)
 * @returns 복호화된 평문 데이터 (Buffer 형태)
 */
function decrypt(ciphertext: Buffer, key: Buffer, iv: Buffer, tag: Buffer): Buffer {
    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(tag); // 인증 태그 설정
    let decrypted = decipher.update(ciphertext);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return decrypted;
}

/**
 * 키 생성 및 관리 함수 (BLE 보안 요구사항 충족)
 * 실제 애플리케이션에서는 안전한 키 관리가 필수입니다.
 */
export function generateKey(length: number): Buffer {
    // 32바이트 (256비트) 키 생성
    return crypto.randomBytes(length / 8);
}

/**
 * 테스트용 더미 함수 - 실제 BLE 통신 시뮬레이션 준비
 */
export function simulateBleCommunication(data: string, key: Buffer, iv: Buffer): { encryptedData: string, ivUsed: string } {
    console.log("--- Simulate BLE Communication ---");
    // 실제로는 이 부분이 BLE 레벨에서 처리되지만, 모듈 테스트를 위해 시뮬레이션합니다.
    const plaintextBuffer = Buffer.from(data, 'utf8');
    const { ciphertext, tag } = encrypt(plaintextBuffer, key, iv);

    return {
        encryptedData: ciphertext.toString('hex'),
        ivUsed: iv.toString('hex')
    };
}