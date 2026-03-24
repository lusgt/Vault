import SwiftUI

struct EntryListView: View {
    @Environment(VaultService.self) private var vault
    @AppStorage("appLanguage") private var language = "zh"
    let entries: [Entry]
    @Binding var selectedEntry: Entry?
    @Binding var searchText: String

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    L10n.emptyListTitle(language, searchText.isEmpty == false),
                    systemImage: searchText.isEmpty ? "lock.rectangle" : "magnifyingglass",
                    description: Text(L10n.emptyListDesc(language, searchText.isEmpty == false))
                )
            } else {
                List(entries, selection: $selectedEntry) { entry in
                    EntryRow(entry: entry)
                        .tag(entry)
                        .contextMenu {
                            Button(L10n.favoriteHelp(language, entry.isFavorite)) {
                                try? vault.toggleFavorite(entry)
                            }
                            Divider()
                            Button(L10n.archive(language), role: .destructive) {
                                if selectedEntry?.id == entry.id { selectedEntry = nil }
                                try? vault.archiveEntry(entry)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        .searchable(text: $searchText, prompt: L10n.searchPrompt(language))
        .frame(minWidth: 240)
    }
}

struct EntryRow: View {
    let entry: Entry
    @AppStorage("appLanguage") private var language = "zh"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // 风险等级颜色指示点
                Circle()
                    .fill(riskColor)
                    .frame(width: 8, height: 8)

                Text(entry.title)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            HStack(spacing: 6) {
                Label(entry.category.label(in: language), systemImage: entry.category.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !entry.tags.isEmpty {
                    Text(entry.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                SmartTimeView(date: entry.updatedAt)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var riskColor: Color {
        switch entry.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// 30 秒内显示相对时间（"5 秒前"），之后切换为固定格式日期。
// 每个 Row 只设一次单次 Timer，切换后不再刷新，性能友好。
struct SmartTimeView: View {
    let date: Date
    @State private var useFixed: Bool

    init(date: Date) {
        self.date = date
        _useFixed = State(initialValue: Date().timeIntervalSince(date) >= 30)
    }

    var body: some View {
        Group {
            if useFixed {
                Text(date.formatted(date: .abbreviated, time: .shortened))
            } else {
                Text(date, style: .relative)
            }
        }
        .onAppear {
            let age = Date().timeIntervalSince(date)
            guard age < 30 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (30 - age)) {
                useFixed = true
            }
        }
    }
}
