import SwiftUI

// @main 标记这是 App 的入口点。
// AppDelegate 处理"关闭应用时锁定"的逻辑。
@main
struct VaultApp: App {
    @State private var vault = VaultService.shared
    @State private var lockService = LockService.shared
    @AppStorage("appLanguage") private var language = "zh"
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vault)
                .environment(lockService)
                .environment(\.locale, Locale(identifier: language == "en" ? "en" : "zh-Hans"))
                .id(language)
        }
        .windowResizability(.contentSize)
        .commands {
            // 移除不需要的默认菜单项
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // 关闭应用时根据设置决定是否锁定
        if VaultService.shared.settings.lockOnClose {
            VaultService.shared.lock()   // lock() 内部已调用 clearNow()
        } else {
            ClipboardService.shared.clearNow()   // 不锁定但仍清空剪贴板
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
