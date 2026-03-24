import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var language = "zh"

    @State private var exportPassword        = ""
    @State private var exportPasswordConfirm = ""
    @State private var importPassword        = ""
    @State private var message         = ""
    @State private var messageIsError  = false
    @State private var isBusy          = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.backupTitle(language))
                    .font(.headline)
                Spacer()
                Button(L10n.done(language)) { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            Divider()

        Form {
            // ── 导出 ──────────────────────────────────────────────────────────
            Section {
                LeadingSecureField(placeholder: L10n.exportPassword(language), text: $exportPassword)
                    .frame(height: 22)
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                LeadingSecureField(placeholder: L10n.exportPasswordConfirm(language), text: $exportPasswordConfirm)
                    .frame(height: 22)
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                if !exportPassword.isEmpty && !exportPasswordConfirm.isEmpty
                    && exportPassword != exportPasswordConfirm {
                    Text(L10n.exportPwdMismatch(language))
                        .font(.caption).foregroundStyle(.red)
                }

                Button(L10n.saveBackupFile(language)) { saveBackup() }
                    .disabled(exportPassword.count < 12
                              || exportPassword != exportPasswordConfirm
                              || isBusy)
            } header: {
                Label(L10n.exportBackup(language), systemImage: "arrow.up.doc")
            } footer: {
                Text(L10n.exportFooter(language))
                    .font(.caption).foregroundStyle(.secondary)
            }

            // ── 导入 ──────────────────────────────────────────────────────────
            Section {
                LeadingSecureField(placeholder: L10n.importPassword(language), text: $importPassword)
                    .frame(height: 22)
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                Button(L10n.chooseBackupFile(language)) { importBackup() }
                    .disabled(importPassword.isEmpty || isBusy)
            } header: {
                Label(L10n.restoreBackup(language), systemImage: "arrow.down.doc")
            } footer: {
                Text(L10n.importFooter(language))
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(messageIsError ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
        } // VStack
        .frame(width: 460, height: 560)
    }

    // MARK: - 导出

    private func saveBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vault-backup-\(dateString()).vaultbackup"
        panel.allowedContentTypes  = [UTType.data]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            isBusy = true
            Task {
                do {
                    let data = try await vault.exportBackup(backupPassword: exportPassword)
                    try data.write(to: url)
                    showMessage(L10n.exportSaved(language, url.lastPathComponent), isError: false)
                    exportPassword = ""
                    exportPasswordConfirm = ""
                } catch {
                    showMessage(L10n.exportFailed(language, error.localizedDescription), isError: true)
                }
                isBusy = false
            }
        }
    }

    // MARK: - 导入

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes     = [UTType.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let fileData = try? Data(contentsOf: url) else {
                showMessage(L10n.importReadFailed(language), isError: true)
                return
            }
            isBusy = true
            Task {
                do {
                    let count = try await vault.importBackup(fileData: fileData, backupPassword: importPassword)
                    showMessage(L10n.importSuccess(language, count), isError: false)
                    importPassword = ""
                } catch {
                    showMessage(L10n.importFailed(language, error.localizedDescription), isError: true)
                }
                isBusy = false
            }
        }
    }

    // MARK: -

    private func showMessage(_ text: String, isError: Bool) {
        messageIsError = isError
        message        = text
    }

    private func dateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmm"
        return fmt.string(from: Date())
    }
}
