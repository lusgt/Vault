import Foundation
import SQLite3
import CryptoKit

// SQLITE_TRANSIENT 是 C 宏，Swift 不自动桥接，需手动定义。
// 它告诉 SQLite 立即复制传入的数据，不依赖调用方保持缓冲区存活。
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// DatabaseService 封装所有 SQLite 操作。
// 由于 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor，所有方法默认在主线程运行，
// 确保 SQLite 单线程访问安全。
class DatabaseService {
    static let shared = DatabaseService()
    private var db: OpaquePointer?
    private init() {}

    // MARK: - 生命周期

    func open() throws {
        let url = try Self.databaseURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw DBError.openFailed
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA secure_delete=ON;", nil, nil, nil)
        try createTables()
    }

    static func databaseURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { throw DBError.pathError }
        return appSupport.appendingPathComponent("Vault/vault.db")
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func createTables() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS vault_meta (
            id INTEGER PRIMARY KEY DEFAULT 1,
            name TEXT NOT NULL DEFAULT 'Vault',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            kdf_version TEXT NOT NULL DEFAULT 'pbkdf2-sha256-200k',
            cipher_version TEXT NOT NULL DEFAULT 'aes-256-gcm',
            salt BLOB NOT NULL,
            verifier BLOB NOT NULL
        );
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS entries (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            tags_json TEXT NOT NULL DEFAULT '[]',
            content_ciphertext BLOB NOT NULL,
            note_ciphertext BLOB,
            risk_level TEXT NOT NULL DEFAULT 'Medium',
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_viewed_at TEXT
        );
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY DEFAULT 1,
            auto_lock_seconds INTEGER NOT NULL DEFAULT 300,
            clipboard_clear_seconds INTEGER NOT NULL DEFAULT 30,
            lock_on_sleep INTEGER NOT NULL DEFAULT 1,
            lock_on_close INTEGER NOT NULL DEFAULT 1
        );
        """)
        try exec("INSERT OR IGNORE INTO settings (id) VALUES (1);")
        try exec("""
        CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            entry_id TEXT,
            created_at TEXT NOT NULL,
            metadata_json TEXT
        );
        """)
        // 滚动迁移：添加新列（若已存在则忽略错误）
        sqlite3_exec(db, "ALTER TABLE entries ADD COLUMN content_filename TEXT", nil, nil, nil)
        // 元数据加密列（v2）
        sqlite3_exec(db, "ALTER TABLE entries ADD COLUMN title_enc BLOB",    nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE entries ADD COLUMN type_enc BLOB",     nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE entries ADD COLUMN category_enc BLOB", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE entries ADD COLUMN tags_enc BLOB",     nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE entries ADD COLUMN risk_enc BLOB",     nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE entries ADD COLUMN filename_enc BLOB", nil, nil, nil)
        // vault_meta 迁移版本标志（0=明文，1=元数据已加密）
        sqlite3_exec(db, "ALTER TABLE vault_meta ADD COLUMN meta_version INTEGER NOT NULL DEFAULT 0", nil, nil, nil)
    }

    // MARK: - Vault Meta

    func isVaultCreated() -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM vault_meta", -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return false }
        return sqlite3_column_int(stmt, 0) > 0
    }

    func saveVaultMeta(name: String, salt: Data, verifier: Data) throws {
        let now = iso8601(Date())
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "INSERT OR REPLACE INTO vault_meta (id, name, created_at, updated_at, salt, verifier) VALUES (1,?,?,?,?,?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.execFailed("prepare failed")
        }
        bind(stmt, 1, name)
        bind(stmt, 2, now)
        bind(stmt, 3, now)
        bind(stmt, 4, salt)
        bind(stmt, 5, verifier)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func updateVaultMeta(salt: Data, verifier: Data, kdfVersion: String = "pbkdf2-sha256-200k") throws {
        let now = iso8601(Date())
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "UPDATE vault_meta SET salt=?, verifier=?, kdf_version=?, updated_at=? WHERE id=1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.execFailed("prepare failed")
        }
        bind(stmt, 1, salt)
        bind(stmt, 2, verifier)
        bind(stmt, 3, kdfVersion)
        bind(stmt, 4, now)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func loadVaultMeta() -> (salt: Data, verifier: Data, kdfVersion: String)? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT salt, verifier, kdf_version FROM vault_meta WHERE id=1", -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let saltPtr = sqlite3_column_blob(stmt, 0) else { return nil }
        let salt = Data(bytes: saltPtr, count: Int(sqlite3_column_bytes(stmt, 0)))
        guard let verPtr = sqlite3_column_blob(stmt, 1) else { return nil }
        let verifier = Data(bytes: verPtr, count: Int(sqlite3_column_bytes(stmt, 1)))
        let kdfVersion = col(stmt, 2) ?? "pbkdf2-sha256-200k"
        return (salt, verifier, kdfVersion)
    }

    // MARK: - Entries

    func insertEntry(_ e: Entry, key: SymmetricKey) throws {
        let crypto = CryptoService.shared
        let titleEnc   = try crypto.encrypt(e.title,              key: key)
        let typeEnc    = try crypto.encrypt(e.type.rawValue,      key: key)
        let catEnc     = try crypto.encrypt(e.category.rawValue,  key: key)
        let tagsEnc    = try crypto.encrypt(jsonEncode(e.tags),   key: key)
        let riskEnc    = try crypto.encrypt(e.riskLevel.rawValue, key: key)
        let filenameEnc = e.contentFilename.flatMap { try? crypto.encrypt($0, key: key) }

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        // title/type/category 仍是 NOT NULL 列，写空字符串占位；
        // rowToEntry 优先读 _enc 列，这些占位值不会被实际使用。
        let sql = """
        INSERT INTO entries
        (id, title, type, category,
         content_ciphertext, note_ciphertext, is_favorite, is_archived, created_at, updated_at,
         title_enc, type_enc, category_enc, tags_enc, risk_enc, filename_enc)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.execFailed("prepare failed")
        }
        bind(stmt, 1, e.id.uuidString)
        bind(stmt, 2, "")   // 占位
        bind(stmt, 3, "")   // 占位
        bind(stmt, 4, "")   // 占位
        bind(stmt, 5, e.contentCiphertext)
        bindNullableBlob(stmt, 6, e.noteCiphertext)
        sqlite3_bind_int(stmt, 7, e.isFavorite  ? 1 : 0)
        sqlite3_bind_int(stmt, 8, e.isArchived  ? 1 : 0)
        bind(stmt, 9,  iso8601(e.createdAt))
        bind(stmt, 10, iso8601(e.updatedAt))
        bind(stmt, 11, titleEnc)
        bind(stmt, 12, typeEnc)
        bind(stmt, 13, catEnc)
        bind(stmt, 14, tagsEnc)
        bind(stmt, 15, riskEnc)
        bindNullableBlob(stmt, 16, filenameEnc)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func updateEntry(_ e: Entry, key: SymmetricKey) throws {
        let crypto = CryptoService.shared
        let titleEnc    = try crypto.encrypt(e.title,              key: key)
        let typeEnc     = try crypto.encrypt(e.type.rawValue,      key: key)
        let catEnc      = try crypto.encrypt(e.category.rawValue,  key: key)
        let tagsEnc     = try crypto.encrypt(jsonEncode(e.tags),   key: key)
        let riskEnc     = try crypto.encrypt(e.riskLevel.rawValue, key: key)
        let filenameEnc = e.contentFilename.flatMap { try? crypto.encrypt($0, key: key) }

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = """
        UPDATE entries SET
        content_ciphertext=?, note_ciphertext=?, is_favorite=?, is_archived=?,
        updated_at=?, last_viewed_at=?,
        title_enc=?, type_enc=?, category_enc=?, tags_enc=?, risk_enc=?, filename_enc=?
        WHERE id=?
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.execFailed("prepare failed")
        }
        bind(stmt, 1, e.contentCiphertext)
        bindNullableBlob(stmt, 2, e.noteCiphertext)
        sqlite3_bind_int(stmt, 3, e.isFavorite ? 1 : 0)
        sqlite3_bind_int(stmt, 4, e.isArchived ? 1 : 0)
        bind(stmt, 5, iso8601(e.updatedAt))
        if let lv = e.lastViewedAt { bind(stmt, 6, iso8601(lv)) } else { sqlite3_bind_null(stmt, 6) }
        bind(stmt, 7,  titleEnc)
        bind(stmt, 8,  typeEnc)
        bind(stmt, 9,  catEnc)
        bind(stmt, 10, tagsEnc)
        bind(stmt, 11, riskEnc)
        bindNullableBlob(stmt, 12, filenameEnc)
        bind(stmt, 13, e.id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func deleteEntry(id: UUID) throws {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "DELETE FROM entries WHERE id=?", -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.execFailed("prepare failed")
        }
        bind(stmt, 1, id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func loadAllEntries(key: SymmetricKey) -> [Entry] {
        loadEntries(archived: false, key: key)
    }

    func loadArchivedEntries(key: SymmetricKey) -> [Entry] {
        loadEntries(archived: true, key: key)
    }

    // MARK: - 元数据迁移（明文 → 加密）

    func needsMetadataMigration() -> Bool { metaVersion() == 0 }

    private func metaVersion() -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT meta_version FROM vault_meta WHERE id=1", -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    /// 首次解锁后调用：把所有明文元数据列加密到 _enc 列，清空明文列，写入迁移标志。
    /// 若已迁移（meta_version=1）则立即返回。整个操作在一个事务里，失败时自动回滚。
    func migrateMetadataIfNeeded(key: SymmetricKey) throws {
        guard needsMetadataMigration() else { return }
        let crypto = CryptoService.shared
        sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        do {
            var sel: OpaquePointer?
            defer { sqlite3_finalize(sel) }
            let selSQL = "SELECT id,title,type,category,tags_json,risk_level,content_filename FROM entries WHERE title IS NOT NULL"
            guard sqlite3_prepare_v2(db, selSQL, -1, &sel, nil) == SQLITE_OK else {
                throw DBError.execFailed("migration select failed")
            }
            while sqlite3_step(sel) == SQLITE_ROW {
                guard let idStr = col(sel, 0) else { continue }
                let title    = col(sel, 1) ?? ""
                let typeStr  = col(sel, 2) ?? ""
                let catStr   = col(sel, 3) ?? ""
                let tagsStr  = col(sel, 4) ?? "[]"
                let riskStr  = col(sel, 5) ?? "Medium"
                let filename = col(sel, 6)

                let titleEnc = try crypto.encrypt(title,   key: key)
                let typeEnc  = try crypto.encrypt(typeStr, key: key)
                let catEnc   = try crypto.encrypt(catStr,  key: key)
                let tagsEnc  = try crypto.encrypt(tagsStr, key: key)
                let riskEnc  = try crypto.encrypt(riskStr, key: key)
                let fnEnc    = filename.flatMap { try? crypto.encrypt($0, key: key) }

                var upd: OpaquePointer?
                defer { sqlite3_finalize(upd) }
                // 用空字符串占位：NOT NULL 约束不允许 NULL，
                // 迁移后这些列不再被读取（rowToEntry 优先读 _enc 列）。
                // content_filename 无 NOT NULL 约束，可以置 NULL。
                let updSQL = """
                UPDATE entries SET
                  title='', type='', category='', tags_json='[]', risk_level='',
                  content_filename=NULL,
                  title_enc=?, type_enc=?, category_enc=?, tags_enc=?, risk_enc=?, filename_enc=?
                WHERE id=?
                """
                guard sqlite3_prepare_v2(db, updSQL, -1, &upd, nil) == SQLITE_OK else {
                    throw DBError.execFailed("migration update failed")
                }
                bind(upd, 1, titleEnc); bind(upd, 2, typeEnc); bind(upd, 3, catEnc)
                bind(upd, 4, tagsEnc);  bind(upd, 5, riskEnc)
                bindNullableBlob(upd, 6, fnEnc)
                bind(upd, 7, idStr)
                guard sqlite3_step(upd) == SQLITE_DONE else {
                    throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
                }
            }
            guard sqlite3_exec(db, "UPDATE vault_meta SET meta_version=1 WHERE id=1", nil, nil, nil) == SQLITE_OK else {
                throw DBError.execFailed("meta_version update failed")
            }
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        } catch {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw error
        }
    }

    // MARK: - Private entry loading

    private func loadEntries(archived: Bool, key: SymmetricKey) -> [Entry] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        // Columns 0-7: id, content_ct, note_ct, is_fav, is_arch, created_at, updated_at, last_viewed
        // Columns 8-13: title_enc, type_enc, category_enc, tags_enc, risk_enc, filename_enc (preferred)
        // Columns 14-19: title, type, category, tags_json, risk_level, content_filename (migration fallback)
        let sql = """
        SELECT id, content_ciphertext, note_ciphertext, is_favorite, is_archived,
               created_at, updated_at, last_viewed_at,
               title_enc, type_enc, category_enc, tags_enc, risk_enc, filename_enc,
               title, type, category, tags_json, risk_level, content_filename
        FROM entries WHERE is_archived=\(archived ? 1 : 0) ORDER BY updated_at DESC
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        var results: [Entry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let e = rowToEntry(stmt, key: key) { results.append(e) }
        }
        return results
    }

    private func rowToEntry(_ stmt: OpaquePointer?, key: SymmetricKey) -> Entry? {
        guard let stmt,
              let idStr = col(stmt, 0), let id = UUID(uuidString: idStr)
        else { return nil }

        guard let contentCT = readBlob(stmt, 1) else { return nil }
        let noteCT = readBlob(stmt, 2)

        let isFavorite = sqlite3_column_int(stmt, 3) != 0
        let isArchived = sqlite3_column_int(stmt, 4) != 0
        let fmt = ISO8601DateFormatter()
        let createdAt  = col(stmt, 5).flatMap { fmt.date(from: $0) } ?? Date()
        let updatedAt  = col(stmt, 6).flatMap { fmt.date(from: $0) } ?? Date()
        let lastViewed = col(stmt, 7).flatMap { fmt.date(from: $0) }

        let crypto = CryptoService.shared

        // Prefer encrypted columns (8-13), fall back to plaintext (14-19) for pre-migration rows
        func decMeta(_ encIdx: Int32, _ plainIdx: Int32) -> String? {
            if let d = readBlob(stmt, encIdx), let s = try? crypto.decryptToString(d, key: key) { return s }
            return col(stmt, plainIdx)
        }

        guard let title    = decMeta(8,  14),
              let typeStr  = decMeta(9,  15), let type = EntryType(rawValue: typeStr),
              let catStr   = decMeta(10, 16), let category = EntryCategory(rawValue: catStr)
        else { return nil }

        let tagsJson = decMeta(11, 17) ?? "[]"
        let tags = (try? JSONDecoder().decode([String].self, from: tagsJson.data(using: .utf8) ?? Data())) ?? []
        let riskStr = decMeta(12, 18) ?? "Medium"
        let riskLevel = RiskLevel(rawValue: riskStr) ?? .medium
        let contentFilename = decMeta(13, 19)

        return Entry(id: id, title: title, type: type, category: category, tags: tags,
                     contentCiphertext: contentCT, noteCiphertext: noteCT,
                     contentFilename: contentFilename, riskLevel: riskLevel,
                     isFavorite: isFavorite, isArchived: isArchived,
                     createdAt: createdAt, updatedAt: updatedAt, lastViewedAt: lastViewed)
    }

    private func readBlob(_ stmt: OpaquePointer?, _ idx: Int32) -> Data? {
        guard let ptr = sqlite3_column_blob(stmt, idx) else { return nil }
        let count = Int(sqlite3_column_bytes(stmt, idx))
        guard count > 0 else { return nil }
        return Data(bytes: ptr, count: count)
    }

    // MARK: - Settings

    struct AppSettings {
        var autoLockSeconds: Int = 300
        var clipboardClearSeconds: Int = 30
        var lockOnSleep: Bool = true
        var lockOnClose: Bool = true
    }

    func loadSettings() -> AppSettings {
        var s = AppSettings()
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT auto_lock_seconds,clipboard_clear_seconds,lock_on_sleep,lock_on_close FROM settings WHERE id=1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return s }
        s.autoLockSeconds = Int(sqlite3_column_int(stmt, 0))
        s.clipboardClearSeconds = Int(sqlite3_column_int(stmt, 1))
        s.lockOnSleep = sqlite3_column_int(stmt, 2) != 0
        s.lockOnClose = sqlite3_column_int(stmt, 3) != 0
        return s
    }

    func saveSettings(_ s: AppSettings) throws {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "UPDATE settings SET auto_lock_seconds=?,clipboard_clear_seconds=?,lock_on_sleep=?,lock_on_close=? WHERE id=1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.execFailed("prepare failed")
        }
        sqlite3_bind_int(stmt, 1, Int32(s.autoLockSeconds))
        sqlite3_bind_int(stmt, 2, Int32(s.clipboardClearSeconds))
        sqlite3_bind_int(stmt, 3, s.lockOnSleep ? 1 : 0)
        sqlite3_bind_int(stmt, 4, s.lockOnClose ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Audit

    func log(action: String, entryId: UUID? = nil, meta: [String: String]? = nil, key: SymmetricKey? = nil) {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "INSERT INTO audit_logs (action,entry_id,created_at,metadata_json) VALUES (?,?,?,?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        bind(stmt, 1, action)
        if let eid = entryId { bind(stmt, 2, eid.uuidString) } else { sqlite3_bind_null(stmt, 2) }
        bind(stmt, 3, iso8601(Date()))
        if let meta, let data = try? JSONEncoder().encode(meta) {
            if let key {
                if let enc = try? CryptoService.shared.encrypt(data, key: key) {
                    bind(stmt, 4, "enc:\(enc.base64EncodedString())")
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
            } else {
                // No key available: avoid persisting sensitive metadata in plaintext.
                sqlite3_bind_null(stmt, 4)
            }
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        _ = sqlite3_step(stmt)
    }

    // MARK: - Helpers

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String) {
        // SQLITE_TRANSIENT: SQLite copies the string immediately so the Swift buffer
        // can be freed before sqlite3_step() is called.
        sqlite3_bind_text(stmt, idx, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
    }

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ value: Data) {
        // withUnsafeBytes pointer is only valid inside the closure; SQLITE_TRANSIENT
        // ensures SQLite copies the blob before the closure (and the pointer) exits.
        value.withUnsafeBytes { ptr in
            _ = sqlite3_bind_blob(stmt, idx, ptr.baseAddress, Int32(ptr.count), SQLITE_TRANSIENT)
        }
    }

    /// lock() 时调用：把 WAL 帧 checkpoint 到主库并截断 WAL 文件，
    /// 防止已删除/更新条目的明文元数据在 WAL 中残留。
    func checkpointWAL() {
        sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
    }

    private func bindNullableBlob(_ stmt: OpaquePointer?, _ idx: Int32, _ value: Data?) {
        if let v = value { bind(stmt, idx, v) } else { sqlite3_bind_null(stmt, idx) }
    }

    private func col(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        sqlite3_column_text(stmt, idx).map { String(cString: $0) }
    }

    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func jsonEncode(_ tags: [String]) -> String {
        (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}

enum DBError: LocalizedError {
    case openFailed, execFailed(String), pathError

    var errorDescription: String? {
        let lang = L10n.currentLang()
        switch self {
        case .openFailed: return L10n.errDbOpenFailed(lang)
        case .execFailed(let m): return L10n.errDbExecFailed(lang, m)
        case .pathError: return L10n.errDbPathError(lang)
        }
    }
}
