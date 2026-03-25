import SwiftUI

// LockView 是 App 启动时的第一个界面，有两种状态：
// 1. 首次使用：创建主密码
// 2. 之后每次：输入主密码解锁
struct LockView: View {
    @Environment(VaultService.self) private var vault

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showRetryHint = false
    @AppStorage("unlockFailCount") private var failCount = 0   // 持久化，重启后不清零
    @State private var capsLockOn = false
    @State private var capsLockMonitor: Any? = nil
    @AppStorage("appLanguage") private var language = "zh"

    private var isFirstTime: Bool { vault.isFirstTime }

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // 图标 + 标题
                VStack(spacing: 12) {
                    VaultLogoView(size: 88)
                    Text("Vault")
                        .font(.largeTitle.bold())
                    Text(isFirstTime ? L10n.createVaultTitle(language) : L10n.unlockTitle(language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 输入区域
                VStack(spacing: 12) {
                    SecureField(isFirstTime ? L10n.setMasterPassword(language) : L10n.masterPassword(language),
                                text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                        .onSubmit { handleSubmit() }
                        .onChange(of: password) { _, _ in showRetryHint = false }

                    if isFirstTime {
                        SecureField(L10n.confirmPassword(language), text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                            .onSubmit { handleSubmit() }
                    }

                    // 大写锁定提示（始终占位，避免布局抖动）
                    HStack(spacing: 4) {
                        Image(systemName: "capslock.fill")
                        Text(L10n.capsLockOn(language))
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .opacity(capsLockOn ? 1 : 0)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(width: 280)
                    }
                }

                // 按钮
                Button(action: handleSubmit) {
                    Group {
                        if vault.isLoading {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(L10n.verifying(language))
                            }
                        } else {
                            Text(isFirstTime ? L10n.createVault(language) : L10n.unlock(language))
                        }
                    }
                    .frame(width: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vault.isLoading || password.isEmpty)
                .keyboardShortcut(.return)

                if showRetryHint {
                    Text(L10n.retryHint(language))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(48)
        }
        .frame(width: 420, height: 480)
        .onAppear {
            capsLockOn = NSEvent.modifierFlags.contains(.capsLock)
            capsLockMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                capsLockOn = event.modifierFlags.contains(.capsLock)
                return event
            }
        }
        .onDisappear {
            if let monitor = capsLockMonitor {
                NSEvent.removeMonitor(monitor)
                capsLockMonitor = nil
            }
        }
    }

    private func handleSubmit() {
        errorMessage = ""
        showRetryHint = false
        guard !password.isEmpty else { return }

        if isFirstTime {
            guard password.count >= 12 else {
                errorMessage = L10n.passwordTooShort(language)
                return
            }
            guard password == confirmPassword else {
                errorMessage = L10n.passwordMismatch(language)
                confirmPassword = ""
                return
            }
            Task {
                do {
                    try await vault.createVault(password: password)
                    LockService.shared.startTimer(seconds: vault.settings.autoLockSeconds)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            // 连续输错增加延迟（delay 基于当前 failCount，即本次实际等待时间）
            let delay = failCount > 2 ? min(Double(failCount - 2) * 2.0, 10.0) : 0
            Task {
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                do {
                    try await vault.unlock(password: password)
                    LockService.shared.startTimer(seconds: vault.settings.autoLockSeconds)
                    failCount = 0
                    showRetryHint = false
                } catch VaultError.wrongPassword {
                    failCount += 1
                    // 用递增后的 failCount 计算下次等待时间，供提示展示
                    let nextDelay = failCount > 2 ? min(Double(failCount - 2) * 2.0, 10.0) : 0
                    errorMessage = L10n.wrongPassword(language, Int(nextDelay))
                    showRetryHint = nextDelay > 0
                    password = ""
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
