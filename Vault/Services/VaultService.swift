import Foundation
import CryptoKit
import Observation

// VaultService 是整个 App 的核心协调器。
// @Observable 是 Swift 的新观察机制，视图中用到的属性发生变化时，视图自动更新。
// 单例模式：整个 App 只有一个实例，所有视图共享同一份状态。
@Observable
class VaultService {
    static let shared = VaultService()

    var isUnlocked = false
    var isFirstTime = false
    var isLoading = false
    var entries: [Entry] = []
    var settings: DatabaseService.AppSettings = .init()
    var lastError: String?

    private(set) var key: SymmetricKey?

    private let db = DatabaseService.shared
    private let crypto = CryptoService.shared

    private init() {
        do {
            try db.open()
            isFirstTime = !db.isVaultCreated()
            settings = db.loadSettings()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 创建密码本（首次使用）

    func createVault(password: String) async throws {
        guard password.count >= 12 else { throw VaultError.passwordTooShort }

        isLoading = true
        defer { isLoading = false }

        let salt = crypto.generateSalt()
        let derivedKey = try await deriveKeyInBackground(password: password, salt: salt)
        let verifier = try crypto.createVerifier(key: derivedKey)

        try db.saveVaultMeta(name: "Vault", salt: salt, verifier: verifier)
        self.key = derivedKey
        isFirstTime = false
        isUnlocked = true
        db.log(action: "vault_created")
    }

    // MARK: - 解锁 / 锁定

    func unlock(password: String) async throws {
        guard let meta = db.loadVaultMeta() else { throw VaultError.vaultNotFound }

        isLoading = true
        defer { isLoading = false }

        // 密钥派生在后台线程运行（约 0.5-1 秒），不阻塞 UI
        let derivedKey = try await deriveKeyInBackground(password: password, salt: meta.salt,
                                                         kdfVersion: meta.kdfVersion)

        guard crypto.verifyKey(derivedKey, verifier: meta.verifier) else {
            throw VaultError.wrongPassword
        }

        self.key = derivedKey
        isUnlocked = true
        // 首次解锁后将明文元数据迁移到加密列（之后立即完成，幂等）
        try? db.migrateMetadataIfNeeded(key: derivedKey)
        entries = db.loadAllEntries(key: derivedKey)
        settings = db.loadSettings()
        db.log(action: "unlocked")
    }

    func lock() {
        ClipboardService.shared.clearNow()
        key = nil
        entries = []
        isUnlocked = false
        db.log(action: "locked")
        db.checkpointWAL()
    }

    // MARK: - 条目操作

    // MARK: - 二进制条目（图片/截图/文件）

    func createBinaryEntry(
        title: String, type: EntryType, category: EntryCategory,
        data: Data, filename: String?, note: String = "", tags: [String] = [],
        riskLevel: RiskLevel, isFavorite: Bool = false
    ) throws {
        guard let key else { throw VaultError.locked }
        let contentCT = try crypto.encrypt(data, key: key)
        let noteCT = note.isEmpty ? nil : try crypto.encrypt(note, key: key)
        let entry = Entry(
            title: title, type: type, category: category, tags: tags,
            contentCiphertext: contentCT, noteCiphertext: noteCT,
            contentFilename: filename, riskLevel: riskLevel, isFavorite: isFavorite
        )
        try db.insertEntry(entry, key: key)
        entries.insert(entry, at: 0)
        db.log(action: "entry_created", entryId: entry.id)
    }

    func decryptBinaryContent(_ entry: Entry) throws -> Data {
        guard let key else { throw VaultError.locked }
        markViewed(entry)
        db.log(action: "entry_viewed", entryId: entry.id)
        return try crypto.decrypt(entry.contentCiphertext, key: key)
    }

    // 替换二进制条目的内容（保持原 UUID，避免先删后建导致数据丢失）
    func updateBinaryEntryContent(
        _ entry: Entry, data: Data, filename: String?,
        title: String, type: EntryType, category: EntryCategory,
        note: String, tags: [String], riskLevel: RiskLevel, isFavorite: Bool
    ) throws {
        guard let key else { throw VaultError.locked }
        var updated = entry
        updated.title = title
        updated.type = type
        updated.category = category
        updated.tags = tags
        updated.riskLevel = riskLevel
        updated.isFavorite = isFavorite
        updated.contentCiphertext = try crypto.encrypt(data, key: key)
        updated.noteCiphertext = note.isEmpty ? nil : try crypto.encrypt(note, key: key)
        updated.contentFilename = filename
        updated.updatedAt = Date()
        try db.updateEntry(updated, key: key)
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = updated
        }
        db.log(action: "entry_updated", entryId: entry.id)
    }

    // 仅更新二进制条目的元数据（不替换加密内容），note 可选
    func updateBinaryEntryMeta(
        _ entry: Entry, title: String, type: EntryType, category: EntryCategory,
        note: String, tags: [String], riskLevel: RiskLevel, isFavorite: Bool
    ) throws {
        guard let key else { throw VaultError.locked }
        var updated = entry
        updated.title = title
        updated.type = type
        updated.category = category
        updated.tags = tags
        updated.riskLevel = riskLevel
        updated.isFavorite = isFavorite
        updated.noteCiphertext = note.isEmpty ? nil : try crypto.encrypt(note, key: key)
        updated.updatedAt = Date()
        try db.updateEntry(updated, key: key)
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = updated
        }
        db.log(action: "entry_updated", entryId: entry.id)
    }

    // MARK: - 文本条目

    func createEntry(
        title: String, type: EntryType, category: EntryCategory,
        content: String, note: String = "", tags: [String] = [],
        riskLevel: RiskLevel, isFavorite: Bool = false
    ) throws {
        guard let key else { throw VaultError.locked }

        let contentCT = try crypto.encrypt(content, key: key)
        let noteCT = note.isEmpty ? nil : try crypto.encrypt(note, key: key)

        let entry = Entry(
            title: title, type: type, category: category, tags: tags,
            contentCiphertext: contentCT, noteCiphertext: noteCT,
            riskLevel: riskLevel, isFavorite: isFavorite
        )
        try db.insertEntry(entry, key: key)
        entries.insert(entry, at: 0)
        db.log(action: "entry_created", entryId: entry.id)
    }

    func updateEntry(_ entry: Entry, title: String, type: EntryType, category: EntryCategory,
                     content: String, note: String, tags: [String],
                     riskLevel: RiskLevel, isFavorite: Bool) throws {
        guard let key else { throw VaultError.locked }

        var updated = entry
        updated.title = title
        updated.type = type
        updated.category = category
        updated.tags = tags
        updated.riskLevel = riskLevel
        updated.isFavorite = isFavorite
        updated.contentCiphertext = try crypto.encrypt(content, key: key)
        updated.noteCiphertext = note.isEmpty ? nil : try crypto.encrypt(note, key: key)
        updated.updatedAt = Date()

        try db.updateEntry(updated, key: key)
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = updated
        }
        db.log(action: "entry_updated", entryId: entry.id)
    }

    func toggleFavorite(_ entry: Entry) throws {
        guard let key else { throw VaultError.locked }
        var updated = entry
        updated.isFavorite.toggle()
        updated.updatedAt = Date()
        try db.updateEntry(updated, key: key)
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = updated
        }
    }

    func archiveEntry(_ entry: Entry) throws {
        guard let key else { throw VaultError.locked }
        var updated = entry
        updated.isArchived = true
        updated.updatedAt = Date()
        try db.updateEntry(updated, key: key)
        entries.removeAll { $0.id == entry.id }
        db.log(action: "entry_archived", entryId: entry.id)
        db.checkpointWAL()
    }

    func restoreEntry(_ entry: Entry) throws {
        guard let key else { throw VaultError.locked }
        var updated = entry
        updated.isArchived = false
        updated.updatedAt = Date()
        try db.updateEntry(updated, key: key)
        entries.insert(updated, at: 0)
        db.log(action: "entry_restored", entryId: entry.id)
    }

    func loadArchivedEntries() -> [Entry] {
        guard let key else { return [] }
        return db.loadArchivedEntries(key: key)
    }

    func deleteEntry(_ entry: Entry) throws {
        try db.deleteEntry(id: entry.id)
        entries.removeAll { $0.id == entry.id }
        db.log(action: "entry_deleted", entryId: entry.id)
        db.checkpointWAL()
    }

    // MARK: - 解密

    func decryptContent(_ entry: Entry) throws -> String {
        guard let key else { throw VaultError.locked }
        markViewed(entry)
        db.log(action: "entry_viewed", entryId: entry.id)
        return try crypto.decryptToString(entry.contentCiphertext, key: key)
    }

    func decryptNote(_ entry: Entry) throws -> String? {
        guard let key else { throw VaultError.locked }
        guard let noteCT = entry.noteCiphertext else { return nil }
        return try crypto.decryptToString(noteCT, key: key)
    }

    private func markViewed(_ entry: Entry) {
        guard let key else { return }
        var updated = entry
        updated.lastViewedAt = Date()
        try? db.updateEntry(updated, key: key)
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = updated
        }
    }

    // MARK: - 备份与恢复

    func exportBackup(backupPassword: String) async throws -> Data {
        guard let key else { throw VaultError.locked }
        return try await BackupService.shared.export(entries: entries, vaultKey: key, backupPassword: backupPassword)
    }

    /// 导入备份，返回实际写入的条目数（已存在的 ID 跳过）
    func importBackup(fileData: Data, backupPassword: String) async throws -> Int {
        guard let key else { throw VaultError.locked }
        let imported = try await BackupService.shared.restore(from: fileData, backupPassword: backupPassword, vaultKey: key)
        let existingIDs = Set(entries.map(\.id))
        var count = 0
        for entry in imported {
            guard !existingIDs.contains(entry.id) else { continue }
            try db.insertEntry(entry, key: key)
            entries.insert(entry, at: 0)
            count += 1
        }
        if count > 0 { db.log(action: "backup_imported") }
        return count
    }

    // MARK: - 设置

    func saveSettings() throws {
        try db.saveSettings(settings)
    }

    // MARK: - 修改主密码

    func changePassword(current: String, newPassword: String) async throws {
        guard let meta = db.loadVaultMeta() else { throw VaultError.vaultNotFound }
        guard newPassword.count >= 12 else { throw VaultError.passwordTooShort }

        isLoading = true
        defer { isLoading = false }

        let currentKey = try await deriveKeyInBackground(password: current, salt: meta.salt,
                                                         kdfVersion: meta.kdfVersion)
        guard crypto.verifyKey(currentKey, verifier: meta.verifier) else {
            throw VaultError.wrongPassword
        }

        let newSalt = crypto.generateSalt()
        let newKey = try await deriveKeyInBackground(password: newPassword, salt: newSalt)

        // 用新密钥重新加密所有条目（包括二进制条目）
        for entry in entries {
            var updated = entry
            // 文本条目和二进制条目都用原始 Data 解密再加密，避免 UTF-8 转换问题
            let contentData = try crypto.decrypt(entry.contentCiphertext, key: currentKey)
            updated.contentCiphertext = try crypto.encrypt(contentData, key: newKey)
            if let noteCT = entry.noteCiphertext {
                let note = try crypto.decryptToString(noteCT, key: currentKey)
                updated.noteCiphertext = try crypto.encrypt(note, key: newKey)
            }
            try db.updateEntry(updated, key: newKey)
        }

        let newVerifier = try crypto.createVerifier(key: newKey)
        try db.updateVaultMeta(salt: newSalt, verifier: newVerifier)
        self.key = newKey
        db.log(action: "password_changed")
    }

    // MARK: - 私有

    // 把耗时的密钥派生放到后台线程，避免冻结 UI。
    // kdfVersion 必须是已知版本，否则抛出 unknownKDFVersion，
    // 防止未来 KDF 升级后旧 App 版本用错误算法解密。
    private func deriveKeyInBackground(password: String, salt: Data,
                                       kdfVersion: String = "pbkdf2-sha256-200k") async throws -> SymmetricKey {
        guard kdfVersion == "pbkdf2-sha256-200k" else {
            throw VaultError.unknownKDFVersion
        }
        let crypto = self.crypto
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let key = try crypto.deriveKey(password: password, salt: salt)
                    continuation.resume(returning: key)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum VaultError: LocalizedError {
    case passwordTooShort, wrongPassword, vaultNotFound, locked, unknownKDFVersion

    var errorDescription: String? {
        let lang = L10n.currentLang()
        switch self {
        case .passwordTooShort:    return L10n.passwordTooShort(lang)
        case .wrongPassword:       return L10n.errVaultWrongPassword(lang)
        case .vaultNotFound:       return L10n.errVaultNotFound(lang)
        case .locked:              return L10n.errVaultLocked(lang)
        case .unknownKDFVersion:   return L10n.errVaultUnknownKDF(lang)
        }
    }
}
