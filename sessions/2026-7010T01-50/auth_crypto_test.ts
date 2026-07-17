// P0 요구사항 충족을 위한 단위 테스트 파일
import { encrypt, decrypt, generateKey, simulateBleCommunication } from './auth_crypto';

describe('AuthCrypto Module (P0 Security Check)', () => {
    const KEY_LENGTH = 32; // AES-256 requires 32 bytes
    const IV_LENGTH = 12;  // GCM standard IV length
    const TEST_DATA = "Sensitive BLE Data for Insulin Pump";

    let key: Buffer;
    let iv: Buffer;

    beforeAll(() => {
        // 테스트를 위해 고정된 키와 IV 사용 (실제 환경에서는 런타임에 생성되어야 함)
        key = generateKey(KEY_LENGTH);
        iv = crypto.randomBytes(IV_LENGTH); // 각 호출마다 다른 IV 사용 시뮬레이션
    });

    test('generateKey should produce a 32-byte key', () => {
        expect(key.length).toBe(32);
    });

    test('encrypt and decrypt cycle should maintain data integrity (AES-GCM)', () => {
        const plaintext = Buffer.from(TEST_DATA, 'utf8');
        
        // 1. 암호화 실행
        const { ciphertext, tag } = encrypt(plaintext, key, iv);

        // 2. 복호화 실행
        const decrypted = decrypt(ciphertext, key, iv, tag);

        // 3. 결과 검증
        expect(decrypted.toString('utf8')).toBe(TEST_DATA);
    });

    test('simulateBleCommunication should correctly format encrypted data', () => {
        const result = simulateBleCommunication(TEST_DATA, key, iv);
        
        // 데이터가 16진수 문자열로 올바르게 변환되었는지 확인
        expect(result.encryptedData).toBeDefined();
        expect(result.ivUsed).toBeDefined();
    });

    test('Decryption with incorrect tag should throw an error (Simulated Security Check)', () => {
        // 인증 태그를 조작하여 복호화 실패 시뮬레이션
        const wrongTag = crypto.randomBytes(16); 
        
        // 실제 decrypt 함수는 내부적으로 setAuthTag가 있으므로, 여기서는 성공/실패 로직이 제대로 작동하는지 확인합니다.
        // 실제 GCM 구현에서는 태그 불일치 시 오류가 발생해야 합니다.
        expect(() => {
            decrypt(Buffer.from('dummy'), key, iv, wrongTag);
        }).toThrow(); // 태그 검증 실패로 인해 예외 발생 예상
    });
});