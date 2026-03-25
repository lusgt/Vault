import AppKit
import ScreenCaptureKit

// ScreenCaptureService 实现交互式截图（ScreenCaptureKit）：
// 1. 弹出全屏选区覆盖层（拖拽选区）
// 2. 覆盖层 orderOut 后，调用 SCShareableContent 截取正确的显示器
// 3. 裁剪到选区，返回 PNG Data
//
// 多显示器说明：
// - quartzRect 使用全局 CG 坐标系（原点在主显示器左上角，Y 向下）
// - mouseUp 将 Cocoa 坐标转换为 CG 坐标时，使用 CGMainDisplayID 的高度（菜单栏屏），
//   而非 NSScreen.main（当前焦点屏），这两者在多显示器下可能不同
// - capture 根据 quartzRect 中心点找到对应的 SCDisplay，并减去该显示器的全局偏移后裁剪
class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private init() {}

    // 交互式截图主入口。completion 在主线程回调，data 为 PNG，nil 表示取消/失败。
    func captureInteractive(completion: @escaping (Data?) -> Void) {
        showOverlay { [weak self] quartzRect in
            guard let self, let rect = quartzRect else { completion(nil); return }
            Task {
                let data = await self.captureRegion(rect)
                completion(data)
            }
        }
    }

    private func captureRegion(_ quartzRect: CGRect) async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            // 找到包含选区中心点的显示器（全局 CG 坐标系匹配）
            let mid = CGPoint(x: quartzRect.midX, y: quartzRect.midY)
            let display = content.displays.first {
                CGDisplayBounds($0.displayID).contains(mid)
            } ?? content.displays.first
            guard let display else { return nil }
            return await Self.capture(quartzRect: quartzRect, display: display)
        } catch {
            return nil
        }
    }

    private static func capture(quartzRect: CGRect, display: SCDisplay) async -> Data? {
        do {
            // 找到该显示器对应的 NSScreen，取其 backingScaleFactor
            let scale: CGFloat = NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? CGDirectDisplayID) == display.displayID
            }?.backingScaleFactor ?? 2

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.captureResolution = .best
            config.showsCursor = false

            // quartzRect 是全局 CG 坐标（原点在主显示器左上角，Y 向下）
            // CGDisplayBounds 也是全局 CG 坐标，减去显示器原点得到显示器内偏移（单位：点）
            // sourceRect 使用显示器的点坐标（逻辑像素），width/height 使用物理像素
            let displayBounds = CGDisplayBounds(display.displayID)
            let localRect = CGRect(
                x: quartzRect.minX - displayBounds.minX,
                y: quartzRect.minY - displayBounds.minY,
                width:  quartzRect.width,
                height: quartzRect.height
            )
            guard localRect.width > 1, localRect.height > 1 else { return nil }
            config.sourceRect = localRect
            config.width = Int(localRect.width * scale)
            config.height = Int(localRect.height * scale)

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: config
            )
            let nsImage = NSImage(cgImage: cgImage, size: quartzRect.size)
            return nsImage.pngData()
        } catch {
            return nil
        }
    }

    private func showOverlay(completion: @escaping (CGRect?) -> Void) {
        guard let screen = NSScreen.main else { completion(nil); return }
        let panel = ScreenshotOverlayPanel(screen: screen, completion: completion)
        panel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - 全屏选区覆盖层

final class ScreenshotOverlayPanel: NSPanel {
    private let completion: (CGRect?) -> Void

    init(screen: NSScreen, completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.draggingWindow)))
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false
        let view = OverlayView(frame: screen.frame, panel: self)
        contentView = view
        makeFirstResponder(view)
    }

    func finish(with rect: CGRect?) {
        orderOut(nil)
        completion(rect)
    }
}

// MARK: - 选区 NSView

final class OverlayView: NSView {
    weak var panel: ScreenshotOverlayPanel?
    private var startPoint: NSPoint = .zero
    private var selectionRect: NSRect = .zero
    private var isDragging = false

    init(frame: NSRect, panel: ScreenshotOverlayPanel) {
        self.panel = panel
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.38).setFill()
        bounds.fill()

        if isDragging && selectionRect.width > 2 && selectionRect.height > 2 {
            NSGraphicsContext.current?.cgContext.clear(selectionRect)

            NSColor.white.withAlphaComponent(0.9).setStroke()
            let border = NSBezierPath(rect: selectionRect)
            border.lineWidth = 1.5
            border.stroke()

            let label = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.5)
            ]
            let str = NSAttributedString(string: label, attributes: attrs)
            str.draw(at: NSPoint(x: selectionRect.midX - str.size().width / 2,
                                 y: selectionRect.maxY + 6))
        } else {
            let hint = L10n.screenCaptureHint(L10n.currentLang())
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let str = NSAttributedString(string: hint, attributes: attrs)
            str.draw(at: NSPoint(x: (bounds.width  - str.size().width)  / 2,
                                 y: (bounds.height - str.size().height) / 2))
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        isDragging = false
        selectionRect = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(
            x: min(startPoint.x, pt.x), y: min(startPoint.y, pt.y),
            width: abs(pt.x - startPoint.x), height: abs(pt.y - startPoint.y)
        )
        isDragging = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, selectionRect.width > 5, selectionRect.height > 5 else {
            panel?.finish(with: nil)
            return
        }
        // Cocoa 屏幕坐标（全局，原点在菜单栏屏左下角，Y 向上）→ CG 坐标（原点在菜单栏屏左上角，Y 向下）
        // 必须用 CGMainDisplayID 的高度，而非 NSScreen.main（多显示器下两者可能不同）
        let screenRect = window?.convertToScreen(selectionRect) ?? selectionRect
        let primaryH = CGDisplayBounds(CGMainDisplayID()).height
        let quartzRect = CGRect(
            x: screenRect.origin.x,
            y: primaryH - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )
        panel?.finish(with: quartzRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { panel?.finish(with: nil) } // Esc
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}

// MARK: - NSImage → PNG

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
