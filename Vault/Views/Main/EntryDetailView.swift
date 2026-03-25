import SwiftUI
import AppKit

// EntryDetailView 是右侧详情面板。
// 文本内容默认隐藏，点击"显示"后临时解密展示，切换条目时自动隐藏。
// 二进制内容（图片/截图/文件）点击"查看"后解密展示，图片可预览，文件可导出。
struct EntryDetailView: View {
    @Environment(VaultService.self) private var vault
    let entry: Entry
    @Binding var selectedEntry: Entry?

    @State private var revealedContent: String? = nil
    @State private var revealedNote: String? = nil
    @State private var revealedBinaryData: Data? = nil
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showCopyConfirm = false
    @State private var pendingHighRiskAction: (() -> Void)? = nil
    @State private var copyConfirmMessage = ""
    @State private var errorMessage = ""
    @AppStorage("appLanguage") private var language = "zh"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                if entry.isTextContent {
                    contentSection
                } else {
                    binaryContentSection
                }
                if entry.noteCiphertext != nil { noteSection }
                metaSection
                actionButtons
            }
            .padding(24)
        }
        .onChange(of: entry.id) {
            revealedContent = nil
            revealedNote = nil
            revealedBinaryData = nil
            errorMessage = ""
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showEdit = true }) {
                    Label(L10n.edit(language), systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EntryFormView(existingEntry: entry) { showEdit = false }
        }
        .alert(L10n.highRiskTitle(language), isPresented: Binding(
            get: { pendingHighRiskAction != nil },
            set: { if !$0 { pendingHighRiskAction = nil } }
        )) {
            Button(L10n.proceedAnyway(language), role: .destructive) {
                pendingHighRiskAction?()
                pendingHighRiskAction = nil
            }
            Button(L10n.cancel(language), role: .cancel) {
                pendingHighRiskAction = nil
            }
        } message: {
            Text(L10n.highRiskMessage(language, entry.title))
        }
        .alert(L10n.confirmArchiveTitle(language, entry.isArchived), isPresented: $showDeleteConfirm) {
            Button(entry.isArchived ? L10n.deleteForever(language) : L10n.archive(language), role: .destructive) {
                selectedEntry = nil
                if entry.isArchived {
                    try? vault.deleteEntry(entry)
                } else {
                    try? vault.archiveEntry(entry)
                }
            }
            Button(L10n.cancel(language), role: .cancel) {}
        } message: {
            Text(L10n.confirmArchiveMessage(language, entry.isArchived))
        }
        .overlay(alignment: .top) {
            if !copyConfirmMessage.isEmpty {
                Text(copyConfirmMessage)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copyConfirmMessage)
    }

    // MARK: - 子视图

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: entry.type.icon)
                        .foregroundStyle(Color.accentColor)
                    Text(entry.title)
                        .font(.title2.bold())
                }
                HStack(spacing: 8) {
                    riskBadge
                    Label(entry.category.label(in: language), systemImage: entry.category.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: { try? vault.toggleFavorite(entry) }) {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(entry.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.favoriteHelp(language, entry.isFavorite))
        }
    }

    private var riskBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: entry.riskLevel.icon)
            Text(entry.riskLevel.label(in: language))
        }
        .font(.caption.bold())
        .foregroundStyle(riskColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(riskColor.opacity(0.1), in: Capsule())
    }

    private var riskColor: Color {
        switch entry.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    // MARK: - 文本内容区

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.detailContent(language), systemImage: "key.horizontal")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let content = revealedContent {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("••••••••••••••••")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }

            if let err = errorMessage.isEmpty ? nil : errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Button(revealedContent == nil ? L10n.show(language) : L10n.hide(language)) {
                    toggleReveal()
                }
                .buttonStyle(.bordered)

                Button(L10n.copy(language)) { copyContent() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - 二进制内容区

    private var binaryContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(binaryContentLabel, systemImage: entry.type.icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let data = revealedBinaryData {
                if entry.type.isImageContent, let nsImage = NSImage(data: data) {
                    // 图片预览
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                } else {
                    // 文件信息
                    HStack(spacing: 12) {
                        Image(systemName: entry.type.icon)
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.contentFilename ?? L10n.fileNameUntitled(language))
                                .font(.body)
                            Text(fileSizeLabel(data.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                }

                if let err = errorMessage.isEmpty ? nil : errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                HStack(spacing: 8) {
                    Button(L10n.hide(language)) {
                        revealedBinaryData = nil
                        revealedNote = nil
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.export(language)) { exportBinaryData(data) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                // 未解密状态
                HStack(spacing: 12) {
                    Image(systemName: entry.type.icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        if let filename = entry.contentFilename {
                            Text(filename)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        Text(L10n.fileInfoHint(language))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                if let err = errorMessage.isEmpty ? nil : errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                Button(L10n.view(language)) { revealBinaryContent() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var binaryContentLabel: String {
        switch entry.type {
        case .imagePhoto: return L10n.binaryLabelImage(language)
        case .screenshot: return L10n.binaryLabelScreenshot(language)
        case .fileAttachment: return L10n.binaryLabelAttachment(language)
        case .otpBackup: return L10n.binaryLabelOtp(language)
        default: return L10n.detailContent(language)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.detailNote(language), systemImage: "text.quote")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let note = revealedNote {
                Text(note.isEmpty ? L10n.noNote(language) : note)
                    .font(.body)
                    .foregroundStyle(note.isEmpty ? .tertiary : .primary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("••••••")
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !entry.tags.isEmpty {
                HStack {
                    Label(L10n.detailMetaTags(language), systemImage: "tag")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    FlowTagView(tags: entry.tags)
                }
            }
            metaRow(L10n.createdAt(language), value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
            metaRow(L10n.updatedAt(language), value: entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
            if let lv = entry.lastViewedAt {
                metaRow(L10n.lastViewed(language), value: lv.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func metaRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            if entry.isArchived {
                Button(L10n.restore(language)) {
                    try? vault.restoreEntry(entry)
                    selectedEntry = nil
                }
                .buttonStyle(.bordered)

                Button(L10n.deleteForever(language), role: .destructive) { showDeleteConfirm = true }
                    .buttonStyle(.bordered)
            } else {
                Button(L10n.archive(language)) { showDeleteConfirm = true }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 逻辑

    private func toggleReveal() {
        errorMessage = ""
        if revealedContent != nil {
            revealedContent = nil
            revealedNote = nil
        } else if entry.riskLevel == .high {
            pendingHighRiskAction = { doRevealText() }
        } else {
            doRevealText()
        }
    }

    private func doRevealText() {
        do {
            revealedContent = try vault.decryptContent(entry)
            revealedNote = try vault.decryptNote(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revealBinaryContent() {
        errorMessage = ""
        if entry.riskLevel == .high {
            pendingHighRiskAction = { doRevealBinary() }
        } else {
            doRevealBinary()
        }
    }

    private func doRevealBinary() {
        do {
            revealedBinaryData = try vault.decryptBinaryContent(entry)
            revealedNote = try vault.decryptNote(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportBinaryData(_ data: Data) {
        if entry.riskLevel == .high {
            pendingHighRiskAction = { doExportBinaryData(data) }
        } else {
            doExportBinaryData(data)
        }
    }

    private func doExportBinaryData(_ data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = entry.contentFilename ?? defaultExportFilename
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                // 导出失败：在 UI 上显示错误
                DispatchQueue.main.async {
                    self.errorMessage = L10n.exportFailedMessage(self.language, error.localizedDescription)
                }
            }
        }
    }

    private var defaultExportFilename: String {
        switch entry.type {
        case .imagePhoto: return "\(entry.title).png"
        case .screenshot: return "\(entry.title).png"
        case .otpBackup: return "\(entry.title).json"
        default: return entry.title
        }
    }

    private func copyContent() {
        if entry.riskLevel == .high {
            pendingHighRiskAction = {
                if let content = try? vault.decryptContent(entry) { doCopy(content) }
            }
        } else if let content = revealedContent {
            doCopy(content)
        } else if let content = try? vault.decryptContent(entry) {
            doCopy(content)
        }
    }

    private func doCopy(_ text: String) {
        ClipboardService.shared.copy(text, clearAfterSeconds: vault.settings.clipboardClearSeconds)
        DatabaseService.shared.log(action: "entry_copied", entryId: entry.id)
        withAnimation {
            copyConfirmMessage = L10n.copyToast(language, vault.settings.clipboardClearSeconds)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { copyConfirmMessage = "" }
        }
    }

    private func fileSizeLabel(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

// 标签流式布局
struct FlowTagView: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
