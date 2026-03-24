import SwiftUI

struct SettingsView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var showBackup = false
    @State private var saveMessage = ""
    @AppStorage("appLanguage") private var language = "zh"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.settings(language))
                    .font(.headline)
                Spacer()
                Button(L10n.done(language)) { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section(L10n.autoLock(language)) {
                    // vault.settings 是值类型，需要用 Bindable 或直接 binding
                    Picker(L10n.idleAutoLock(language), selection: Binding(
                        get: { vault.settings.autoLockSeconds },
                        set: { vault.settings.autoLockSeconds = $0 }
                    )) {
                        Text(L10n.min(language, 1)).tag(60)
                        Text(L10n.min(language, 5)).tag(300)
                        Text(L10n.min(language, 15)).tag(900)
                        Text(L10n.min(language, 30)).tag(1800)
                        Text(L10n.never(language)).tag(0)
                    }

                    Toggle(L10n.lockOnSleep(language), isOn: Binding(
                        get: { vault.settings.lockOnSleep },
                        set: { vault.settings.lockOnSleep = $0 }
                    ))

                    Toggle(L10n.lockOnClose(language), isOn: Binding(
                        get: { vault.settings.lockOnClose },
                        set: { vault.settings.lockOnClose = $0 }
                    ))
                }

                Section(L10n.clipboard(language)) {
                    Picker(L10n.clipboardClear(language), selection: Binding(
                        get: { vault.settings.clipboardClearSeconds },
                        set: { vault.settings.clipboardClearSeconds = $0 }
                    )) {
                        Text(L10n.sec(language, 15)).tag(15)
                        Text(L10n.sec(language, 30)).tag(30)
                        Text(L10n.sec(language, 60)).tag(60)
                        Text(L10n.never(language)).tag(0)
                    }
                }

                Section(L10n.languageSection(language)) {
                    Picker(L10n.uiLanguage(language), selection: $language) {
                        Text(L10n.languageOptionZh(language)).tag("zh")
                        Text(L10n.languageOptionEn(language)).tag("en")
                    }
                    .pickerStyle(.segmented)
                }

                Section(L10n.security(language)) {
                    Button(L10n.changePassword(language)) { showChangePassword = true }
                        .foregroundStyle(.primary)
                }

                Section(L10n.backupSection(language)) {
                    Button(L10n.backupTitle(language) + "…") { showBackup = true }
                        .foregroundStyle(.primary)
                }

                if !saveMessage.isEmpty {
                    Section {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(L10n.saveSettings(language)) { saveSettings() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 420, height: 560)
        .sheet(isPresented: $showBackup) {
            BackupView()
                .environment(vault)
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
    }

    private func saveSettings() {
        do {
            try vault.saveSettings()
            LockService.shared.startTimer(seconds: vault.settings.autoLockSeconds)
            saveMessage = L10n.saved(language)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveMessage = "" }
        } catch {
            saveMessage = L10n.saveFailed(language, error.localizedDescription)
        }
    }
}

struct ChangePasswordView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var language = "zh"

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.changePasswordTitle(language))
                    .font(.headline)
                Spacer()
                Button(L10n.cancel(language)) { dismiss() }
            }
            .padding()
            Divider()

            Form {
                Section {
                    SecureField(L10n.currentPassword(language), text: $currentPassword)
                }
                Section {
                    SecureField(L10n.newPassword(language), text: $newPassword)
                    SecureField(L10n.confirmNewPassword(language), text: $confirmPassword)
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(L10n.confirmChange(language)) { handleChange() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 340)
    }

    private func handleChange() {
        guard newPassword == confirmPassword else {
            errorMessage = L10n.newPasswordMismatch(language)
            return
        }
        isLoading = true
        Task {
            do {
                try await vault.changePassword(current: currentPassword, newPassword: newPassword)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
