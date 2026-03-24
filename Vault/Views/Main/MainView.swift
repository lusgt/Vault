import SwiftUI

// SidebarFilter 决定中间列显示哪些条目
enum SidebarFilter: Hashable {
    case all
    case favorites
    case recent
    case archived
    case category(EntryCategory)
    case tag(String)
}

// MainView 是解锁后的主界面，使用 NavigationSplitView 实现三栏布局：
// 左栏（分类/标签筛选）→ 中栏（条目列表）→ 右栏（条目详情）
struct MainView: View {
    @Environment(VaultService.self) private var vault
    @AppStorage("appLanguage") private var language = "zh"

    @State private var filter: SidebarFilter = .all
    @State private var selectedEntry: Entry?
    @State private var showNewEntry = false
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .updatedAt

    enum SortOrder: String, CaseIterable {
        case updatedAt
        case title
        case favoritesFirst
    }

    var filteredEntries: [Entry] {
        // 已归档条目从数据库单独加载，不在 vault.entries 里
        let base: [Entry]
        if filter == .archived {
            base = vault.loadArchivedEntries()
        } else {
            base = vault.entries.filter { entry in
                switch filter {
                case .all: return true
                case .favorites: return entry.isFavorite
                case .recent:
                    let threeDaysAgo = Date().addingTimeInterval(-3 * 86400)
                    return (entry.lastViewedAt ?? .distantPast) >= threeDaysAgo
                case .archived: return false  // 不会走到这里
                case .category(let c): return entry.category == c
                case .tag(let t): return entry.tags.contains(t)
                }
            }
        }

        let searched: [Entry]
        if searchText.isEmpty {
            searched = base
        } else {
            searched = base.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return searched.sorted { a, b in
            switch sortOrder {
            case .updatedAt: return a.updatedAt > b.updatedAt
            case .title: return a.title.localizedCompare(b.title) == .orderedAscending
            case .favoritesFirst:
                if a.isFavorite != b.isFavorite { return a.isFavorite }
                return a.updatedAt > b.updatedAt
            }
        }
    }

    var allTags: [String] {
        Array(Set(vault.entries.flatMap(\.tags))).sorted()
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(filter: $filter, allTags: allTags)
        } content: {
            EntryListView(
                entries: filteredEntries,
                selectedEntry: $selectedEntry,
                searchText: $searchText
            )
            .navigationTitle(navigationTitle)
        } detail: {
            if let entry = selectedEntry {
                EntryDetailView(entry: entry, selectedEntry: $selectedEntry)
            } else {
                ContentUnavailableView(
                    L10n.selectRecord(language),
                    systemImage: "lock.rectangle",
                    description: Text(L10n.selectRecordDesc(language))
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showNewEntry = true }) {
                    Label(L10n.newEntry(language), systemImage: "plus")
                }
                .help(L10n.newEntryHelp(language))
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(L10n.sortLabel(order, lang: language))
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(L10n.sort(language), systemImage: "arrow.up.arrow.down")
                }
                .help(L10n.sortHelp(language))
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { vault.lock() }) {
                    Label(L10n.lock(language), systemImage: "lock")
                }
                .help(L10n.lockHelp(language))
                .keyboardShortcut("l", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings = true }) {
                    Label(L10n.settings(language), systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showNewEntry) {
            EntryFormView(existingEntry: nil) { showNewEntry = false }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var navigationTitle: String {
        L10n.navTitle(for: filter, lang: language)
    }
}
