import SwiftUI
import AppKit

// 锁屏界面专用 Logo：透明背景，只渲染盾牌 + 圆环 + 钥匙孔，无外框
struct VaultLogoView: View {
    var size: CGFloat = 88

    var body: some View {
        Canvas { context, canvasSize in
            context.withCGContext { cgCtx in
                drawShieldLogo(ctx: cgCtx, s: canvasSize.width)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - CoreGraphics 绘制（与 App Icon 同风格，无背景/无外框）

private func drawShieldLogo(ctx: CGContext, s: CGFloat) {
    // SwiftUI Canvas 的 CGContext 原点在左上角、y 向下，
    // 而生成图标时的 CGContext 原点在左下角、y 向上。
    // 翻转 y 轴使绘制结果与 App Icon 一致（尖角朝下）。
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let cs   = CGColorSpaceCreateDeviceRGB()
    let mid  = s / 2
    let cyan = CGColor(red: 0.000, green: 0.906, blue: 1.000, alpha: 1.0)
    let cyanMid = CGColor(red: 0.000, green: 0.700, blue: 1.000, alpha: 1.0)

    func gradCyanBlue() -> CGGradient {
        CGGradient(colorsSpace: cs, colors: [cyan, cyanMid] as CFArray, locations: [0, 1])!
    }

    func gStroke(path: CGPath, lw: CGFloat, p0: CGPoint, p1: CGPoint) {
        ctx.saveGState()
        ctx.setLineWidth(lw)
        ctx.addPath(path)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        let g = gradCyanBlue()
        ctx.drawLinearGradient(g, start: p0, end: p1,
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    // ── Shield ────────────────────────────────────────────────────────────────
    let shW  = s * 0.820
    let shH  = s * 0.880
    let shCX = mid
    let shCY = mid + s * 0.020
    let shield = makeShieldPath(cx: shCX, cy: shCY, w: shW, h: shH)

    // Dark fill
    ctx.setFillColor(CGColor(red: 0.075, green: 0.105, blue: 0.160, alpha: 0.85))
    ctx.addPath(shield); ctx.fillPath()

    // Glow
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.060,
                  color: CGColor(red: 0, green: 0.88, blue: 1.0, alpha: 0.80))
    ctx.setStrokeColor(cyan)
    ctx.setLineWidth(s * 0.030); ctx.addPath(shield); ctx.strokePath()
    ctx.restoreGState()

    // Gradient stroke
    gStroke(path: shield, lw: s * 0.036,
            p0: CGPoint(x: shCX, y: shCY + shH / 2),
            p1: CGPoint(x: shCX, y: shCY - shH / 2))

    // ── Ring ──────────────────────────────────────────────────────────────────
    let rR   = shW * 0.258
    let rCX  = shCX
    let rCY  = shCY + s * 0.012
    let rRect = CGRect(x: rCX - rR, y: rCY - rR, width: rR * 2, height: rR * 2)
    let ring = CGPath(ellipseIn: rRect, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.035,
                  color: CGColor(red: 0, green: 0.88, blue: 1.0, alpha: 0.70))
    ctx.setStrokeColor(cyan)
    ctx.setLineWidth(s * 0.024); ctx.addPath(ring); ctx.strokePath()
    ctx.restoreGState()

    gStroke(path: ring, lw: s * 0.030,
            p0: CGPoint(x: rCX, y: rCY + rR),
            p1: CGPoint(x: rCX, y: rCY - rR))

    // ── Keyhole ───────────────────────────────────────────────────────────────
    let khSize = rR * 0.92
    let kh = makeKeyholePath(cx: rCX, cy: rCY, size: khSize)

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.022,
                  color: CGColor(red: 0, green: 0.88, blue: 1.0, alpha: 0.60))
    ctx.setFillColor(cyan); ctx.addPath(kh); ctx.fillPath()
    ctx.restoreGState()
    ctx.setFillColor(cyan); ctx.addPath(kh); ctx.fillPath()
}

private func makeShieldPath(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
    let T = cy + h * 0.50
    let B = cy - h * 0.50
    let L = cx - w * 0.50
    let R = cx + w * 0.50
    let p = CGMutablePath()
    p.move(to: CGPoint(x: L, y: T - h * 0.15))
    p.addCurve(to:       CGPoint(x: cx - w * 0.14, y: T),
               control1: CGPoint(x: L,            y: T - h * 0.04),
               control2: CGPoint(x: L + w * 0.18, y: T))
    p.addCurve(to:       CGPoint(x: cx + w * 0.14, y: T),
               control1: CGPoint(x: cx - w * 0.04, y: T - h * 0.07),
               control2: CGPoint(x: cx + w * 0.04, y: T - h * 0.07))
    p.addCurve(to:       CGPoint(x: R,             y: T - h * 0.15),
               control1: CGPoint(x: R - w * 0.18,  y: T),
               control2: CGPoint(x: R,             y: T - h * 0.04))
    p.addCurve(to:       CGPoint(x: R - w * 0.07, y: B + h * 0.30),
               control1: CGPoint(x: R + w * 0.03,  y: T - h * 0.42),
               control2: CGPoint(x: R - w * 0.02,  y: B + h * 0.52))
    p.addCurve(to:       CGPoint(x: cx,            y: B),
               control1: CGPoint(x: R - w * 0.10,  y: B + h * 0.14),
               control2: CGPoint(x: cx + w * 0.24, y: B + h * 0.04))
    p.addCurve(to:       CGPoint(x: L + w * 0.07, y: B + h * 0.30),
               control1: CGPoint(x: cx - w * 0.24, y: B + h * 0.04),
               control2: CGPoint(x: L + w * 0.10,  y: B + h * 0.14))
    p.addCurve(to:       CGPoint(x: L,             y: T - h * 0.15),
               control1: CGPoint(x: L + w * 0.02,  y: B + h * 0.52),
               control2: CGPoint(x: L - w * 0.03,  y: T - h * 0.42))
    p.closeSubpath()
    return p
}

private func makeKeyholePath(cx: CGFloat, cy: CGFloat, size: CGFloat) -> CGPath {
    let headR  = size * 0.390
    let headCY = cy + size * 0.090
    let bW     = size * 0.360
    let bH     = size * 0.500
    let bTop   = headCY - headR * 0.50
    let bBot   = bTop - bH
    let bBotW  = bW * 0.50
    let p = CGMutablePath()
    p.addEllipse(in: CGRect(x: cx - headR, y: headCY - headR,
                            width: headR * 2, height: headR * 2))
    p.move(to: CGPoint(x: cx - bW / 2, y: bTop))
    p.addLine(to: CGPoint(x: cx + bW / 2, y: bTop))
    p.addLine(to: CGPoint(x: cx + bBotW / 2, y: bBot))
    p.addLine(to: CGPoint(x: cx - bBotW / 2, y: bBot))
    p.closeSubpath()
    return p
}

