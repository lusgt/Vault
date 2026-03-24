import SwiftUI

struct SidebarView: View {
    @Environment(VaultService.self) private var vault
    @Binding var filter: SidebarFilter
    let allTags: [String]
    @AppStorage("appLanguage") private var language = "zh"

    var body: some View {
        List(selection: $filter) {
            // 快捷入口
            Section {
                Label(L10n.all(language), systemImage: "tray.full")
                    .tag(SidebarFilter.all)
                Label(L10n.favorites(language), systemImage: "star.fill")
                    .tag(SidebarFilter.favorites)
                Label(L10n.recent(language), systemImage: "clock")
                    .tag(SidebarFilter.recent)
                Label(L10n.archived(language), systemImage: "archivebox")
                    .tag(SidebarFilter.archived)
            }

            // 按类别
            Section(L10n.categories(language)) {
                ForEach(EntryCategory.allCases, id: \.self) { category in
                    let count = vault.entries.filter { $0.category == category }.count
                    HStack {
                        Label(category.label(in: language), systemImage: category.icon)
                        Spacer()
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(SidebarFilter.category(category))
                }
            }

            // 按标签
            if !allTags.isEmpty {
                Section(L10n.tags(language)) {
                    ForEach(allTags, id: \.self) { tag in
                        Label("#\(tag)", systemImage: "tag")
                            .tag(SidebarFilter.tag(tag))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }
}
