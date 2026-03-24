import Foundation

/// Lightweight runtime localization backed by Localizable.strings.
/// Uses appLanguage values: "zh" (default) or "en".
enum L10n {
    static func currentLang() -> String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "zh"
    }

    private static func langCode(_ lang: String?) -> String {
        (lang ?? currentLang()) == "en" ? "en" : "zh-Hans"
    }

    private static func bundle(for lang: String?) -> Bundle {
        let code = langCode(lang)
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    static func localized(_ key: String, _ lang: String? = nil) -> String {
        bundle(for: lang).localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ lang: String? = nil, _ args: CVarArg...) -> String {
        let code = langCode(lang)
        let locale = Locale(identifier: code)
        return String(format: localized(key, lang), locale: locale, arguments: args)
    }

    // Sidebar
    static func all(_ lang: String) -> String { localized("sidebar.all", lang) }
    static func favorites(_ lang: String) -> String { localized("sidebar.favorites", lang) }
    static func recent(_ lang: String) -> String { localized("sidebar.recent", lang) }
    static func archived(_ lang: String) -> String { localized("sidebar.archived", lang) }
    static func categories(_ lang: String) -> String { localized("sidebar.categories", lang) }
    static func tags(_ lang: String) -> String { localized("sidebar.tags", lang) }

    static func searchPrompt(_ lang: String) -> String { localized("search.prompt", lang) }

    static func navTitle(for filter: SidebarFilter, lang: String) -> String {
        switch filter {
        case .all: return all(lang)
        case .favorites: return favorites(lang)
        case .recent: return recent(lang)
        case .archived: return archived(lang)
        case .category(let c): return c.label(in: lang)
        case .tag(let t): return "#\(t)"
        }
    }

    static func sortLabel(_ order: MainView.SortOrder, lang: String) -> String {
        switch order {
        case .updatedAt: return localized("sort.updated_at", lang)
        case .title: return localized("sort.title", lang)
        case .favoritesFirst: return localized("sort.favorites_first", lang)
        }
    }

    // Settings
    static func settings(_ lang: String) -> String { localized("settings.title", lang) }
    static func done(_ lang: String) -> String { localized("common.done", lang) }
    static func cancel(_ lang: String) -> String { localized("common.cancel", lang) }
    static func saveSettings(_ lang: String) -> String { localized("settings.save", lang) }
    static func saved(_ lang: String) -> String { localized("settings.saved", lang) }
    static func saveFailed(_ lang: String, _ msg: String) -> String {
        format("settings.save_failed", lang, msg)
    }

    static func autoLock(_ lang: String) -> String { localized("settings.auto_lock", lang) }
    static func idleAutoLock(_ lang: String) -> String { localized("settings.idle_lock", lang) }
    static func lockOnSleep(_ lang: String) -> String { localized("settings.lock_on_sleep", lang) }
    static func lockOnClose(_ lang: String) -> String { localized("settings.lock_on_close", lang) }
    static func clipboard(_ lang: String) -> String { localized("settings.clipboard", lang) }
    static func clipboardClear(_ lang: String) -> String { localized("settings.clipboard_clear", lang) }
    static func security(_ lang: String) -> String { localized("settings.security", lang) }
    static func changePassword(_ lang: String) -> String { localized("settings.change_password", lang) }
    static func backupTitle(_ lang: String) -> String { localized("settings.backup_title", lang) }
    static func backupSection(_ lang: String) -> String { localized("settings.backup", lang) }
    static func languageSection(_ lang: String) -> String { localized("settings.language", lang) }
    static func uiLanguage(_ lang: String) -> String { localized("settings.ui_language", lang) }
    static func languageOptionZh(_ lang: String) -> String { localized("settings.language_option_zh", lang) }
    static func languageOptionEn(_ lang: String) -> String { localized("settings.language_option_en", lang) }

    static func min(_ lang: String, _ n: Int) -> String { format("time.minutes", lang, n) }
    static func sec(_ lang: String, _ n: Int) -> String { format("time.seconds", lang, n) }
    static func never(_ lang: String) -> String { localized("time.never", lang) }

    // Change password
    static func changePasswordTitle(_ lang: String) -> String { localized("change_password.title", lang) }
    static func currentPassword(_ lang: String) -> String { localized("change_password.current", lang) }
    static func newPassword(_ lang: String) -> String { localized("change_password.new", lang) }
    static func confirmNewPassword(_ lang: String) -> String { localized("change_password.confirm", lang) }
    static func confirmChange(_ lang: String) -> String { localized("change_password.confirm_button", lang) }
    static func newPasswordMismatch(_ lang: String) -> String { localized("change_password.mismatch", lang) }

    // Backup
    static func exportBackup(_ lang: String) -> String { localized("backup.export", lang) }
    static func restoreBackup(_ lang: String) -> String { localized("backup.restore", lang) }
    static func exportPassword(_ lang: String) -> String { localized("backup.export_password", lang) }
    static func exportPasswordConfirm(_ lang: String) -> String { localized("backup.export_password_confirm", lang) }
    static func importPassword(_ lang: String) -> String { localized("backup.import_password", lang) }
    static func saveBackupFile(_ lang: String) -> String { localized("backup.save_file", lang) }
    static func chooseBackupFile(_ lang: String) -> String { localized("backup.choose_file", lang) }
    static func exportPwdMismatch(_ lang: String) -> String { localized("backup.password_mismatch", lang) }
    static func exportFooter(_ lang: String) -> String { localized("backup.export_footer", lang) }
    static func importFooter(_ lang: String) -> String { localized("backup.import_footer", lang) }
    static func exportSaved(_ lang: String, _ name: String) -> String { format("backup.saved", lang, name) }
    static func exportFailed(_ lang: String, _ msg: String) -> String { format("backup.export_failed", lang, msg) }
    static func importReadFailed(_ lang: String) -> String { localized("backup.read_failed", lang) }
    static func importSuccess(_ lang: String, _ count: Int) -> String { format("backup.import_success", lang, count) }
    static func importFailed(_ lang: String, _ msg: String) -> String { format("backup.import_failed", lang, msg) }

    // Lock screen
    static func unlockTitle(_ lang: String) -> String { localized("lock.title_unlock", lang) }
    static func createVaultTitle(_ lang: String) -> String { localized("lock.title_create", lang) }
    static func masterPassword(_ lang: String) -> String { localized("lock.master", lang) }
    static func setMasterPassword(_ lang: String) -> String { localized("lock.set_master", lang) }
    static func confirmPassword(_ lang: String) -> String { localized("lock.confirm", lang) }
    static func capsLockOn(_ lang: String) -> String { localized("lock.caps", lang) }
    static func verifying(_ lang: String) -> String { localized("lock.verifying", lang) }
    static func createVault(_ lang: String) -> String { localized("lock.create_button", lang) }
    static func unlock(_ lang: String) -> String { localized("lock.unlock_button", lang) }
    static func retryHint(_ lang: String) -> String { localized("lock.retry_hint", lang) }
    static func passwordTooShort(_ lang: String) -> String { localized("lock.password_too_short", lang) }
    static func passwordMismatch(_ lang: String) -> String { localized("lock.password_mismatch", lang) }
    static func wrongPassword(_ lang: String, _ nextDelay: Int) -> String {
        format("lock.wrong_password", lang, nextDelay)
    }

    // Main toolbar
    static func newEntry(_ lang: String) -> String { localized("main.new", lang) }
    static func newEntryHelp(_ lang: String) -> String { localized("main.new_help", lang) }
    static func sort(_ lang: String) -> String { localized("main.sort", lang) }
    static func sortHelp(_ lang: String) -> String { localized("main.sort_help", lang) }
    static func lock(_ lang: String) -> String { localized("main.lock", lang) }
    static func lockHelp(_ lang: String) -> String { localized("main.lock_help", lang) }
    static func selectRecord(_ lang: String) -> String { localized("main.select_record", lang) }
    static func selectRecordDesc(_ lang: String) -> String { localized("main.select_record_desc", lang) }

    // Entry form
    static func entryFormTitle(_ lang: String, _ editing: Bool) -> String {
        editing ? localized("entry_form.title_edit", lang) : localized("entry_form.title_new", lang)
    }
    static func entryFormBasics(_ lang: String) -> String { localized("entry_form.basics", lang) }
    static func entryFormCancel(_ lang: String) -> String { localized("entry_form.cancel", lang) }
    static func entryFormSave(_ lang: String, _ editing: Bool) -> String {
        editing ? localized("entry_form.save", lang) : localized("entry_form.create", lang)
    }
    static func titleRequired(_ lang: String) -> String { localized("entry_form.title", lang) }
    static func typeLabel(_ lang: String) -> String { localized("entry_form.type", lang) }
    static func categoryLabel(_ lang: String) -> String { localized("entry_form.category", lang) }
    static func riskLabel(_ lang: String) -> String { localized("entry_form.risk", lang) }
    static func favorite(_ lang: String) -> String { localized("entry_form.favorite", lang) }
    static func contentRequired(_ lang: String) -> String { localized("entry_form.content", lang) }
    static func encryptedHint(_ lang: String) -> String { localized("entry_form.encrypted_hint", lang) }
    static func noteOptional(_ lang: String) -> String { localized("entry_form.note", lang) }
    static func tagsOptional(_ lang: String) -> String { localized("entry_form.tags", lang) }
    static func tagsPlaceholder(_ lang: String) -> String { localized("entry_form.tags_placeholder", lang) }
    static func currentFile(_ lang: String) -> String { localized("entry_form.current_file", lang) }
    static func keepOriginal(_ lang: String) -> String { localized("entry_form.keep_original", lang) }
    static func replace(_ lang: String) -> String { localized("entry_form.replace", lang) }
    static func reselect(_ lang: String) -> String { localized("entry_form.reselect", lang) }
    static func captureScreenshot(_ lang: String) -> String { localized("entry_form.capture", lang) }
    static func chooseImage(_ lang: String) -> String { localized("entry_form.choose_image", lang) }
    static func chooseFile(_ lang: String) -> String { localized("entry_form.choose_file", lang) }
    static func chooseOtpFile(_ lang: String) -> String { localized("entry_form.choose_otp_file", lang) }
    static func capturing(_ lang: String) -> String { localized("entry_form.capturing", lang) }
    static func fileLabelImage(_ lang: String) -> String { localized("entry_form.file_label_image", lang) }
    static func fileLabelScreenshot(_ lang: String) -> String { localized("entry_form.file_label_screenshot", lang) }
    static func fileLabelFile(_ lang: String) -> String { localized("entry_form.file_label_file", lang) }
    static func fileLabelOtp(_ lang: String) -> String { localized("entry_form.file_label_otp", lang) }
    static func encryptedLabel(_ lang: String) -> String { localized("entry_form.encrypted_label", lang) }
    static func readFileFailed(_ lang: String, _ msg: String) -> String { format("entry_form.read_file_failed", lang, msg) }
    static func openImageMessage(_ lang: String) -> String { localized("entry_form.open_image_message", lang) }
    static func openFileMessage(_ lang: String) -> String { localized("entry_form.open_file_message", lang) }
    static func openOtpMessage(_ lang: String) -> String { localized("entry_form.open_otp_message", lang) }
    static func screenshotTitlePrefix(_ lang: String) -> String { localized("entry_form.screenshot_prefix", lang) }

    // Entry detail
    static func detailContent(_ lang: String) -> String { localized("detail.content", lang) }
    static func detailNote(_ lang: String) -> String { localized("detail.note", lang) }
    static func detailMetaTags(_ lang: String) -> String { localized("detail.tags", lang) }
    static func createdAt(_ lang: String) -> String { localized("detail.created", lang) }
    static func updatedAt(_ lang: String) -> String { localized("detail.updated", lang) }
    static func lastViewed(_ lang: String) -> String { localized("detail.last_viewed", lang) }
    static func show(_ lang: String) -> String { localized("detail.show", lang) }
    static func hide(_ lang: String) -> String { localized("detail.hide", lang) }
    static func copy(_ lang: String) -> String { localized("detail.copy", lang) }
    static func export(_ lang: String) -> String { localized("detail.export", lang) }
    static func view(_ lang: String) -> String { localized("detail.view", lang) }
    static func archive(_ lang: String) -> String { localized("detail.archive", lang) }
    static func restore(_ lang: String) -> String { localized("detail.restore", lang) }
    static func deleteForever(_ lang: String) -> String { localized("detail.delete_forever", lang) }
    static func edit(_ lang: String) -> String { localized("detail.edit", lang) }
    static func favoriteHelp(_ lang: String, _ isFav: Bool) -> String {
        isFav ? localized("detail.unfavorite", lang) : localized("detail.favorite", lang)
    }

    static func highRiskTitle(_ lang: String) -> String { localized("detail.high_risk_title", lang) }
    static func highRiskMessage(_ lang: String, _ title: String) -> String {
        format("detail.high_risk_message", lang, title)
    }
    static func confirmCopy(_ lang: String) -> String { localized("detail.copy_anyway", lang) }
    static func confirmArchiveTitle(_ lang: String, _ archived: Bool) -> String {
        archived ? localized("detail.confirm_delete_title", lang) : localized("detail.confirm_archive_title", lang)
    }
    static func confirmArchiveMessage(_ lang: String, _ archived: Bool) -> String {
        archived ? localized("detail.confirm_delete_message", lang) : localized("detail.confirm_archive_message", lang)
    }
    static func copyToast(_ lang: String, _ sec: Int) -> String { format("detail.copy_toast", lang, sec) }
    static func exportFailedMessage(_ lang: String, _ msg: String) -> String { format("detail.export_failed", lang, msg) }
    static func noNote(_ lang: String) -> String { localized("detail.no_note", lang) }
    static func fileInfoHint(_ lang: String) -> String { localized("detail.file_info_hint", lang) }
    static func fileNameUntitled(_ lang: String) -> String { localized("detail.file_untitled", lang) }
    static func binaryLabelImage(_ lang: String) -> String { localized("detail.binary_image", lang) }
    static func binaryLabelScreenshot(_ lang: String) -> String { localized("detail.binary_screenshot", lang) }
    static func binaryLabelAttachment(_ lang: String) -> String { localized("detail.binary_attachment", lang) }
    static func binaryLabelOtp(_ lang: String) -> String { localized("detail.binary_otp", lang) }

    // Empty list
    static func emptyListTitle(_ lang: String, _ searching: Bool) -> String {
        searching ? localized("empty.no_results", lang) : localized("empty.no_entries", lang)
    }
    static func emptyListDesc(_ lang: String, _ searching: Bool) -> String {
        searching ? localized("empty.no_results_desc", lang) : localized("empty.no_entries_desc", lang)
    }

    // Errors (services)
    static func errInvalidPassword(_ lang: String) -> String { localized("error.invalid_password", lang) }
    static func errKeyDerivationFailed(_ lang: String) -> String { localized("error.key_derivation_failed", lang) }
    static func errEncryptionFailed(_ lang: String) -> String { localized("error.encryption_failed", lang) }
    static func errDecryptionFailed(_ lang: String) -> String { localized("error.decryption_failed", lang) }
    static func errInvalidData(_ lang: String) -> String { localized("error.invalid_data", lang) }
    static func errDbOpenFailed(_ lang: String) -> String { localized("error.db_open_failed", lang) }
    static func errDbExecFailed(_ lang: String, _ msg: String) -> String { format("error.db_exec_failed", lang, msg) }
    static func errDbPathError(_ lang: String) -> String { localized("error.db_path_error", lang) }
    static func errVaultWrongPassword(_ lang: String) -> String { localized("error.vault_wrong_password", lang) }
    static func errVaultNotFound(_ lang: String) -> String { localized("error.vault_not_found", lang) }
    static func errVaultLocked(_ lang: String) -> String { localized("error.vault_locked", lang) }
    static func errVaultUnknownKDF(_ lang: String) -> String { localized("error.vault_unknown_kdf", lang) }
    static func errBackupWrongPassword(_ lang: String) -> String { localized("error.backup_wrong_password", lang) }
    static func errBackupInvalidFormat(_ lang: String) -> String { localized("error.backup_invalid_format", lang) }
    static func errBackupPasswordTooShort(_ lang: String) -> String { localized("error.backup_password_too_short", lang) }

    // Screen capture
    static func screenCaptureHint(_ lang: String) -> String { localized("screen.capture_hint", lang) }
}
