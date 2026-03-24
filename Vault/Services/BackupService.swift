import Foundation
import CryptoKit

// BackupService 负责加密备份和恢复。
//
// 备份文件格式：
//   [4字节魔数 "VLTB"] [1字节版本 0x02] [32字节 PBKDF2 盐] [AES-256-GCM 加密的 JSON payload]
//
// 备份密码：用户自定义，至少 12 位，经 PBKDF2-SHA256-200k 派生 AES-256 密钥。
//   密码可以手写或记忆，不需要额外的数字化存储。
//   与主密码无关，建议使用不同的密码。
class BackupService {
    static let shared = BackupService()
    private let crypto = CryptoService.shared
    private init() {}

    // MARK: - 导出

    func export(entries: [Entry], vaultKey: SymmetricKey, backupPassword: String) async throws -> Data {
        guard backupPassword.count >= 12 else { throw BackupError.passwordTooShort }
        let salt      = crypto.generateSalt()
        let backupKey = try await deriveKey(password: backupPassword, salt: salt)
        let fmt       = ISO8601DateFormatter()
        var records: [BackupRecord] = []

        for entry in entries {
            // 统一走 Data 路径，同时支持文本和二进制条目
            let contentData = try crypto.decrypt(entry.contentCiphertext, key: vaultKey)
            let contentEnc  = try crypto.encrypt(contentData, key: backupKey)

            var noteB64: String?
            if let noteCT = entry.noteCiphertext {
                let noteData = try crypto.decrypt(noteCT, key: vaultKey)
                noteB64 = try crypto.encrypt(noteData, key: backupKey).base64EncodedString()
            }

            records.append(BackupRecord(
                id:              entry.id.uuidString,
                title:           entry.title,
                type:            entry.type.rawValue,
                category:        entry.category.rawValue,
                tags:            entry.tags,
                contentB64:      contentEnc.base64EncodedString(),
                noteB64:         noteB64,
                contentFilename: entry.contentFilename,
                riskLevel:       entry.riskLevel.rawValue,
                isFavorite:      entry.isFavorite,
                isArchived:      entry.isArchived,
                createdAt:       fmt.string(from: entry.createdAt),
                updatedAt:       fmt.string(from: entry.updatedAt)
            ))
        }

        let payload  = BackupPayload(version: "2", createdAt: fmt.string(from: Date()),
                                     entryCount: records.count, entries: records)
        let jsonData = try JSONEncoder().encode(payload)
        let encData  = try crypto.encrypt(jsonData, key: backupKey)

        var file = Data([0x56, 0x4C, 0x54, 0x42, 0x02])   // "VLTB" + version 2
        file.append(salt)
        file.append(encData)
        return file
    }

    // MARK: - 导入

    func restore(from fileData: Data, backupPassword: String, vaultKey: SymmetricKey) async throws -> [Entry] {
        guard backupPassword.count >= 12 else { throw BackupError.passwordTooShort }
        guard fileData.count > 37,
              fileData.prefix(4) == Data([0x56, 0x4C, 0x54, 0x42]),
              fileData[4] == 0x02
        else { throw BackupError.invalidFormat }

        let salt      = fileData[5..<37]
        let encData   = fileData[37...]
        let backupKey = try await deriveKey(password: backupPassword, salt: Data(salt))

        let jsonData: Data
        do {
            jsonData = try crypto.decrypt(Data(encData), key: backupKey)
        } catch {
            throw BackupError.wrongPassword
        }

        let payload: BackupPayload
        do {
            payload = try JSONDecoder().decode(BackupPayload.self, from: jsonData)
        } catch {
            throw BackupError.invalidFormat
        }

        let fmt = ISO8601DateFormatter()
        var entries: [Entry] = []

        for record in payload.entries {
            guard let contentData = Data(base64Encoded: record.contentB64) else { continue }
            let contentDec = try crypto.decrypt(contentData, key: backupKey)
            let contentEnc = try crypto.encrypt(contentDec, key: vaultKey)

            var noteCT: Data?
            if let b64 = record.noteB64, let noteData = Data(base64Encoded: b64) {
                let noteDec = try crypto.decrypt(noteData, key: backupKey)
                noteCT = try crypto.encrypt(noteDec, key: vaultKey)
            }

            var entry = Entry(
                title:             record.title,
                type:              EntryType(rawValue: record.type) ?? .note,
                category:          EntryCategory(rawValue: record.category) ?? .other,
                contentCiphertext: contentEnc,
                riskLevel:         RiskLevel(rawValue: record.riskLevel) ?? .medium
            )
            if let id = UUID(uuidString: record.id) { entry.id = id }
            entry.tags            = record.tags
            entry.noteCiphertext  = noteCT
            entry.contentFilename = record.contentFilename
            entry.isFavorite      = record.isFavorite
            entry.isArchived      = record.isArchived
            entry.createdAt       = fmt.date(from: record.createdAt) ?? Date()
            entry.updatedAt       = fmt.date(from: record.updatedAt) ?? Date()
            entries.append(entry)
        }

        return entries
    }

    // MARK: - 私有：后台派生密钥

    private func deriveKey(password: String, salt: Data) async throws -> SymmetricKey {
        let crypto = self.crypto
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    cont.resume(returning: try crypto.deriveKey(password: password, salt: salt))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - 内部结构

private struct BackupPayload: Codable {
    let version: String
    let createdAt: String
    let entryCount: Int
    let entries: [BackupRecord]
}

private struct BackupRecord: Codable {
    let id: String
    let title: String
    let type: String
    let category: String
    let tags: [String]
    let contentB64: String
    let noteB64: String?
    let contentFilename: String?
    let riskLevel: String
    let isFavorite: Bool
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String
}

// MARK: - 错误

enum BackupError: LocalizedError {
    case wrongPassword, invalidFormat, passwordTooShort

    var errorDescription: String? {
        let lang = L10n.currentLang()
        switch self {
        case .wrongPassword: return L10n.errBackupWrongPassword(lang)
        case .invalidFormat: return L10n.errBackupInvalidFormat(lang)
        case .passwordTooShort: return L10n.errBackupPasswordTooShort(lang)
        }
    }
}
