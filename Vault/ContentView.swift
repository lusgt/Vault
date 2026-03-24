import SwiftUI

// ContentView 是路由层：根据 vault 是否解锁，决定显示解锁页还是主界面。
struct ContentView: View {
    @Environment(VaultService.self) private var vault

    var body: some View {
        Group {
            if vault.isUnlocked {
                MainView()
            } else {
                LockView()
            }
        }
        // 动画切换：解锁 ↔ 锁定
        .animation(.easeInOut(duration: 0.25), value: vault.isUnlocked)
    }
}
