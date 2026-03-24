import Foundation
import CryptoKit
import CommonCrypto

// CryptoService 负责所有加密操作。
// 标记为 @unchecked Sendable：没有可变状态，所有方法都是纯计算，线程安全。
// nonisolated 让密钥派生可以在后台线程运行，避免阻塞 UI。
final class CryptoService: @unchecked Sendable {
    static let shared = CryptoService()
    private init() {}

    private let saltSize = 32          // 32 字节随机盐
    private let keySize = 32           // AES-256 需要 32 字节密钥
    private let iterations: UInt32 = 200_000   // PBKDF2 迭代次数，越高越安全但越慢
    private let verifierPlaintext = "VAULT_VERIFY_OK_V1"

    // MARK: - 密钥派生 (PBKDF2-SHA256)
    // 从主密码 + 随机盐派生出加密密钥。同样的密码 + 同样的盐 = 同样的密钥。
    nonisolated func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidPassword
        }
        var derivedKey = Data(repeating: 0, count: keySize)
        let result: Int32 = derivedKey.withUnsafeMutableBytes { dkBytes in
            passwordData.withUnsafeBytes { pwBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        dkBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keySize
                    )
                }
            }
        }
        guard result == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return SymmetricKey(data: derivedKey)
    }

    nonisolated func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltSize)
        _ = SecRandomCopyBytes(kSecRandomDefault, saltSize, &bytes)
        return Data(bytes)
    }

    // MARK: - 加密 / 解密 (AES-256-GCM)
    // AES-GCM 会自动生成随机 nonce，并把 nonce+密文+认证标签合并成一个 Data 返回。

    nonisolated func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }
        return combined
    }

    nonisolated func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    nonisolated func encrypt(_ string: String, key: SymmetricKey) throws -> Data {
        guard let data = string.data(using: .utf8) else { throw CryptoError.invalidData }
        return try encrypt(data, key: key)
    }

    nonisolated func decryptToString(_ data: Data, key: SymmetricKey) throws -> String {
        let decrypted = try decrypt(data, key: key)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        return string
    }

    // MARK: - 验证器
    // 用于校验主密码是否正确：把一段已知明文用密钥加密存起来，
    // 解锁时尝试解密，看结果是否匹配。

    nonisolated func createVerifier(key: SymmetricKey) throws -> Data {
        guard let data = verifierPlaintext.data(using: .utf8) else { throw CryptoError.invalidData }
        return try encrypt(data, key: key)
    }

    nonisolated func verifyKey(_ key: SymmetricKey, verifier: Data) -> Bool {
        guard let decrypted = try? decrypt(verifier, key: key),
              let string = String(data: decrypted, encoding: .utf8) else { return false }
        return string == verifierPlaintext
    }
}

enum CryptoError: LocalizedError {
    case invalidPassword, keyDerivationFailed, encryptionFailed, decryptionFailed, invalidData

    var errorDescription: String? {
        let lang = L10n.currentLang()
        switch self {
        case .invalidPassword: return L10n.errInvalidPassword(lang)
        case .keyDerivationFailed: return L10n.errKeyDerivationFailed(lang)
        case .encryptionFailed: return L10n.errEncryptionFailed(lang)
        case .decryptionFailed: return L10n.errDecryptionFailed(lang)
        case .invalidData: return L10n.errInvalidData(lang)
        }
    }
}
