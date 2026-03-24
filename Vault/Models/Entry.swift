import Foundation

struct Entry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var type: EntryType
    var category: EntryCategory
    var tags: [String] = []
    var contentCiphertext: Data
    var noteCiphertext: Data?
    var contentFilename: String?      // 图片/文件的原始文件名（明文元数据）
    var riskLevel: RiskLevel
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastViewedAt: Date?

    // 是否为文本类型（vs 二进制：图片/截图/文件）
    var isTextContent: Bool { type.isTextContent }

    static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum EntryType: String, Codable, CaseIterable, Hashable {
    // 文本类
    case apiKey = "API Key"
    case accessToken = "Access Token"
    case refreshToken = "Refresh Token"
    case databaseCredential = "Database Credential"
    case sshPrivateKey = "SSH Private Key"
    case certificate = "Certificate"
    case walletMnemonic = "Wallet Mnemonic"
    case walletPrivateKey = "Wallet Private Key"
    case recoveryCode = "Recovery Code"
    case note = "Note / Custom"
    // 二进制类
    case imagePhoto = "Image / Photo"
    case screenshot = "Screenshot"
    case fileAttachment = "File Attachment"
    case otpBackup = "OTP Auth Backup"

    var isTextContent: Bool {
        switch self {
        case .imagePhoto, .screenshot, .fileAttachment, .otpBackup: return false
        default: return true
        }
    }

    var isImageContent: Bool {
        self == .imagePhoto || self == .screenshot
    }

    func label(in lang: String) -> String {
        switch self {
        case .apiKey:             return L10n.localized("entry.type.api_key", lang)
        case .accessToken:        return L10n.localized("entry.type.access_token", lang)
        case .refreshToken:       return L10n.localized("entry.type.refresh_token", lang)
        case .databaseCredential: return L10n.localized("entry.type.db_credential", lang)
        case .sshPrivateKey:      return L10n.localized("entry.type.ssh_private_key", lang)
        case .certificate:        return L10n.localized("entry.type.certificate", lang)
        case .walletMnemonic:     return L10n.localized("entry.type.wallet_mnemonic", lang)
        case .walletPrivateKey:   return L10n.localized("entry.type.wallet_private_key", lang)
        case .recoveryCode:       return L10n.localized("entry.type.recovery_code", lang)
        case .note:               return L10n.localized("entry.type.note", lang)
        case .imagePhoto:         return L10n.localized("entry.type.image_photo", lang)
        case .screenshot:         return L10n.localized("entry.type.screenshot", lang)
        case .fileAttachment:     return L10n.localized("entry.type.file_attachment", lang)
        case .otpBackup:          return L10n.localized("entry.type.otp_backup", lang)
        }
    }

    var icon: String {
        switch self {
        case .apiKey: return "key.fill"
        case .accessToken: return "ticket.fill"
        case .refreshToken: return "arrow.clockwise"
        case .databaseCredential: return "cylinder.fill"
        case .sshPrivateKey: return "terminal.fill"
        case .certificate: return "doc.badge.gearshape.fill"
        case .walletMnemonic: return "list.number"
        case .walletPrivateKey: return "bitcoinsign.circle.fill"
        case .recoveryCode: return "arrow.counterclockwise.circle.fill"
        case .note: return "note.text"
        case .imagePhoto: return "photo.fill"
        case .screenshot: return "camera.viewfinder"
        case .fileAttachment: return "paperclip"
        case .otpBackup: return "lock.rotation"
        }
    }
}

enum EntryCategory: String, Codable, CaseIterable, Hashable {
    case apiToken = "API / Token"
    case database = "Database / Infra"
    case sshCert = "SSH / Cert"
    case wallet = "Wallet / Mnemonic"
    case recovery = "Recovery / Backup"
    case other = "Other"

    func label(in lang: String) -> String {
        switch self {
        case .apiToken:  return L10n.localized("entry.category.api_token", lang)
        case .database:  return L10n.localized("entry.category.database", lang)
        case .sshCert:   return L10n.localized("entry.category.ssh_cert", lang)
        case .wallet:    return L10n.localized("entry.category.wallet", lang)
        case .recovery:  return L10n.localized("entry.category.recovery", lang)
        case .other:     return L10n.localized("entry.category.other", lang)
        }
    }

    var icon: String {
        switch self {
        case .apiToken: return "key"
        case .database: return "cylinder"
        case .sshCert: return "lock.shield"
        case .wallet: return "bitcoinsign.circle"
        case .recovery: return "arrow.clockwise.circle"
        case .other: return "doc"
        }
    }
}

enum RiskLevel: String, Codable, CaseIterable, Hashable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var label: String { labelZH }
    private var labelZH: String {
        switch self {
        case .low: return "低风险"
        case .medium: return "中风险"
        case .high: return "高风险"
        }
    }
    func label(in lang: String) -> String {
        switch self {
        case .low: return L10n.localized("risk.low", lang)
        case .medium: return L10n.localized("risk.medium", lang)
        case .high: return L10n.localized("risk.high", lang)
        }
    }

    var icon: String {
        switch self {
        case .low: return "shield"
        case .medium: return "shield.lefthalf.filled"
        case .high: return "shield.fill"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}
