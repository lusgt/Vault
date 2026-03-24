import AppKit
import Observation

// LockService 管理自动锁定逻辑：
// 1. 空闲超时自动锁定
// 2. 系统休眠/锁屏自动锁定
// 3. 监听鼠标/键盘活动来重置计时器
@Observable
class LockService {
    static let shared = LockService()

    private var lockTimer: Timer?
    private var lastActivityTime = Date()

    private init() {
        setupSleepObserver()
        setupActivityMonitor()
    }

    func startTimer(seconds: Int) {
        stopTimer()
        guard seconds > 0 else { return }
        // 每秒检查一次是否超时
        lockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let idle = Date().timeIntervalSince(self.lastActivityTime)
            if idle >= Double(seconds) {
                VaultService.shared.lock()
                self.stopTimer()
            }
        }
    }

    func stopTimer() {
        lockTimer?.invalidate()
        lockTimer = nil
    }

    func recordActivity() {
        lastActivityTime = Date()
    }

    // 监听系统进入休眠
    private func setupSleepObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { _ in
            if VaultService.shared.settings.lockOnSleep {
                VaultService.shared.lock()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { _ in
            if VaultService.shared.settings.lockOnSleep {
                VaultService.shared.lock()
            }
        }
    }

    // 监听鼠标和键盘事件，有活动就重置空闲计时
    private func setupActivityMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown]) { [weak self] event in
            self?.recordActivity()
            return event
        }
    }

    deinit { stopTimer() }
}
