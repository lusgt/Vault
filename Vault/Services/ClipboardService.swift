import AppKit

// ClipboardService 负责复制到剪贴板，并在指定时间后自动清空。
class ClipboardService {
    static let shared = ClipboardService()
    private var clearTask: Task<Void, Never>?
    private init() {}

    /// 立即取消定时任务并清空剪贴板（锁定/退出时调用）。
    func clearNow() {
        clearTask?.cancel()
        NSPasteboard.general.clearContents()
    }

    func copy(_ text: String, clearAfterSeconds seconds: Int) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // 取消上一次的清空任务
        clearTask?.cancel()
        guard seconds > 0 else { return }

        clearTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            NSPasteboard.general.clearContents()
        }
    }
}
