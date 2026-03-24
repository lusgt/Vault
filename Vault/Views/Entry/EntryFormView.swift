import SwiftUI
import AppKit
import UniformTypeIdentifiers

// EntryFormView 是新建/编辑条目的表单，以 Sheet 形式弹出。
// 支持文本条目和二进制条目（图片、截图、文件）两种模式。
struct EntryFormView: View {
    @Environment(VaultService.self) private var vault
    @AppStorage("appLanguage") private var language = "zh"
    let existingEntry: Entry?
    let onDismiss: () -> Void

    @State private var title = ""
    @State private var type: EntryType = .apiKey
    @State private var category: EntryCategory = .apiToken
    @State private var content = ""
    @State private var note = ""
    @State private var tagsText = ""    // 逗号分隔
    @State private var riskLevel: RiskLevel = .medium
    @State private var isFavorite = false
    @State private var errorMessage = ""

    // 二进制内容状态
    @State private var binaryData: Data?
    @State private var binaryFilename: String?
    @State private var isCapturingScreenshot = false

    private var isEditing: Bool { existingEntry != nil }
    private var isBinaryType: Bool { !type.isTextContent }

    // 判断保存按钮是否可用
    private var canSave: Bool {
        if title.isEmpty { return false }
        if isBinaryType {
            // 新建二进制条目需要选择文件/图片；编辑时可以不重新选
            return isEditing || binaryData != nil
        }
        return !content.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L10n.entryFormTitle(language, isEditing))
                    .font(.headline)
                Spacer()
                Button(L10n.entryFormCancel(language)) { onDismiss() }
                    .keyboardShortcut(.escape)
                Button(L10n.entryFormSave(language, isEditing)) { handleSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            // 表单内容
            Form {
                Section(L10n.entryFormBasics(language)) {
                    TextField(L10n.titleRequired(language), text: $title)

                    Picker(L10n.typeLabel(language), selection: $type) {
                        ForEach(EntryType.allCases, id: \.self) { t in
                            Label(t.label(in: language), systemImage: t.icon).tag(t)
                        }
                    }

                    Picker(L10n.categoryLabel(language), selection: $category) {
                        ForEach(EntryCategory.allCases, id: \.self) { c in
                            Label(c.label(in: language), systemImage: c.icon).tag(c)
                        }
                    }

                    Picker(L10n.riskLabel(language), selection: $riskLevel) {
                        ForEach(RiskLevel.allCases, id: \.self) { r in
                            HStack {
                                Image(systemName: r.icon)
                                Text(r.label(in: language))
                            }.tag(r)
                        }
                    }
                    Toggle(L10n.favorite(language), isOn: $isFavorite)
                }

                // 根据类型显示不同的内容输入区
                if isBinaryType {
                    binaryContentSection
                } else {
                    textContentSection
                }

                Section(L10n.noteOptional(language)) {
                    TextEditor(text: $note)
                        .frame(minHeight: 60)
                }

                Section(L10n.tagsOptional(language)) {
                    TextField(L10n.tagsPlaceholder(language), text: $tagsText)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 520, height: 640)
        .onAppear { prefillIfEditing() }
    }

    // MARK: - 文本内容区

    private var textContentSection: some View {
        Section {
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
        } header: {
            HStack {
                Text(L10n.contentRequired(language))
                Spacer()
                Text(L10n.encryptedHint(language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 二进制内容区

    private var binaryContentSection: some View {
        Section {
            if let data = binaryData {
                // 已选择文件：显示预览 / 文件信息
                binaryPreview(data: data)

                Button(L10n.reselect(language)) { triggerBinaryPicker() }
                    .buttonStyle(.bordered)
            } else if isEditing {
                // 编辑已有条目：当前内容保持不变
                HStack {
                    Image(systemName: type.icon)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(existingEntry?.contentFilename ?? L10n.currentFile(language))
                            .font(.body)
                        Text(L10n.keepOriginal(language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.replace(language)) { triggerBinaryPicker() }
                        .buttonStyle(.bordered)
                }
            } else {
                // 新建：显示选择按钮
                binaryPickerButtons
            }

            if isCapturingScreenshot {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L10n.capturing(language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text(binaryHeaderLabel)
                Spacer()
                Text(L10n.encryptedLabel(language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var binaryHeaderLabel: String {
        switch type {
        case .imagePhoto: return L10n.fileLabelImage(language)
        case .screenshot: return L10n.fileLabelScreenshot(language)
        case .fileAttachment: return L10n.fileLabelFile(language)
        case .otpBackup: return L10n.fileLabelOtp(language)
        default: return L10n.fileLabelFile(language)
        }
    }

    @ViewBuilder
    private func binaryPreview(data: Data) -> some View {
        if type.isImageContent, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .cornerRadius(6)
        } else {
            HStack {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading) {
                    Text(binaryFilename ?? L10n.fileNameUntitled(language))
                        .font(.body)
                    Text(fileSizeLabel(data.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var binaryPickerButtons: some View {
        VStack(spacing: 10) {
            if type == .screenshot {
                Button {
                    captureScreenshot()
                } label: {
                    Label(L10n.captureScreenshot(language), systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCapturingScreenshot)
            }

            if type == .imagePhoto {
                Button {
                    openImagePanel()
                } label: {
                    Label(L10n.chooseImage(language), systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if type == .fileAttachment || type == .otpBackup {
                Button {
                    openFilePanel()
                } label: {
                    Label(type == .otpBackup ? L10n.chooseOtpFile(language) : L10n.chooseFile(language),
                          systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 逻辑

    private func triggerBinaryPicker() {
        if type == .imagePhoto {
            openImagePanel()
        } else if type == .screenshot {
            captureScreenshot()
        } else {
            openFilePanel()
        }
    }

    // 用 NSOpenPanel 直接弹出文件选择窗口（比 fileImporter 更可靠）
    private func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = L10n.openImageMessage(language)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            loadFile(from: url)
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = type == .otpBackup
            ? L10n.openOtpMessage(language)
            : L10n.openFileMessage(language)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            loadFile(from: url)
        }
    }

    private func loadFile(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            binaryData = data
            binaryFilename = url.lastPathComponent
            if title.isEmpty { title = url.deletingPathExtension().lastPathComponent }
        } catch {
            errorMessage = L10n.readFileFailed(language, error.localizedDescription)
        }
    }

    private func captureScreenshot() {
        isCapturingScreenshot = true
        ScreenCaptureService.shared.captureInteractive { data in
            isCapturingScreenshot = false
            guard let data = data else { return }
            binaryData = data
            binaryFilename = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
            // 截图完成后，如果标题为空则自动填充
            if title.isEmpty {
                title = L10n.screenshotTitlePrefix(language) + Date().formatted(date: .abbreviated, time: .shortened)
            }
        }
    }

    private func fileSizeLabel(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }

    private func prefillIfEditing() {
        guard let entry = existingEntry else { return }
        title = entry.title
        type = entry.type
        category = entry.category
        riskLevel = entry.riskLevel
        isFavorite = entry.isFavorite
        tagsText = entry.tags.joined(separator: ", ")
        if entry.isTextContent {
            content = (try? vault.decryptContent(entry)) ?? ""
            note = (try? vault.decryptNote(entry)) ?? ""
        } else {
            note = (try? vault.decryptNote(entry)) ?? ""
        }
    }

    private func handleSave() {
        errorMessage = ""
        let tags = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            if isBinaryType {
                if let entry = existingEntry {
                    // 编辑二进制条目
                    if let newData = binaryData {
                        // 替换了文件：原地更新，保持 UUID，避免先删后建的数据丢失风险
                        try vault.updateBinaryEntryContent(
                            entry, data: newData, filename: binaryFilename,
                            title: title, type: type, category: category,
                            note: note, tags: tags,
                            riskLevel: riskLevel, isFavorite: isFavorite
                        )
                    } else {
                        // 仅更新元数据（标题、分类、备注等），保留原始加密内容
                        try vault.updateBinaryEntryMeta(
                            entry, title: title, type: type, category: category,
                            note: note, tags: tags,
                            riskLevel: riskLevel, isFavorite: isFavorite
                        )
                    }
                } else {
                    guard let data = binaryData else { return }
                    try vault.createBinaryEntry(
                        title: title, type: type, category: category,
                        data: data, filename: binaryFilename,
                        note: note, tags: tags,
                        riskLevel: riskLevel, isFavorite: isFavorite
                    )
                }
            } else {
                if let entry = existingEntry {
                    try vault.updateEntry(
                        entry, title: title, type: type, category: category,
                        content: content, note: note, tags: tags,
                        riskLevel: riskLevel, isFavorite: isFavorite
                    )
                } else {
                    try vault.createEntry(
                        title: title, type: type, category: category,
                        content: content, note: note, tags: tags,
                        riskLevel: riskLevel, isFavorite: isFavorite
                    )
                }
            }
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
