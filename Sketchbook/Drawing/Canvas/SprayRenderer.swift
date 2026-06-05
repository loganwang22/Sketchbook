import UIKit
import CoreGraphics

/// Generates and draws the app's own paint brushes (spray, flow airbrush, oil). PencilKit
/// has no airbrush/oil ink, so these are rendered as particles by us.
enum SprayRenderer {

    /// Per-style generation: spread from the path, sample spacing, particles per sample,
    /// radius range (× nozzle where noted) and opacity range.
    private struct Params {
        var spread: CGFloat, spacing: CGFloat, perSample: Int
        var rMin: CGFloat, rMax: CGFloat, aMin: CGFloat, aMax: CGFloat
    }
    private static func params(_ style: SpraySplat.Style, nozzle: CGFloat) -> Params {
        switch style {
        case .spray:    // fine hard speckles flung wide
            return Params(spread: max(nozzle * 4, 16), spacing: max(nozzle * 0.5, 2.5), perSample: 7,
                          rMin: 0.8, rMax: 2.4, aMin: 0.35, aMax: 0.9)
        case .airbrush: // soft translucent dabs that build up near the path
            return Params(spread: max(nozzle * 1.6, 10), spacing: max(nozzle * 0.35, 2), perSample: 5,
                          rMin: nozzle * 0.35, rMax: nozzle * 0.7, aMin: 0.04, aMax: 0.12)
        case .oil:      // big opaque dabs hugging the path → a thick, slightly lumpy stroke
            return Params(spread: max(nozzle * 0.35, 2), spacing: max(nozzle * 0.2, 1.5), perSample: 3,
                          rMin: nozzle * 0.45, rMax: nozzle * 0.85, aMin: 0.85, aMax: 1.0)
        }
    }

    /// Appends particles for the segment a→b (content space) to `splat` in real time.
    static func scatter(into splat: inout SpraySplat, from a: CGPoint, to b: CGPoint,
                        nozzle: CGFloat, style: SpraySplat.Style) {
        let p = params(style, nozzle: nozzle)
        let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y) / p.spacing))
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps)
            let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            for _ in 0..<p.perSample {
                let off = (CGFloat.random(in: -1...1) + CGFloat.random(in: -1...1)) / 2
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let dist = off * p.spread
                splat.xs.append(Float(c.x + cos(angle) * dist))
                splat.ys.append(Float(c.y + sin(angle) * dist))
                splat.rs.append(Float(CGFloat.random(in: p.rMin...max(p.rMin, p.rMax))))
                splat.alphas.append(Float(CGFloat.random(in: p.aMin...p.aMax)))
            }
        }
    }

    /// Removes particles within `radius` of the segment a→b. Empty splats are dropped.
    static func erase(_ splats: [SpraySplat], alongFrom a: CGPoint, to b: CGPoint,
                      radius: CGFloat) -> [SpraySplat] {
        let r2 = radius * radius
        var result: [SpraySplat] = []
        for splat in splats {
            var xs: [Float] = [], ys: [Float] = [], rs: [Float] = [], alphas: [Float] = []
            for i in 0..<splat.count {
                let p = CGPoint(x: CGFloat(splat.xs[i]), y: CGFloat(splat.ys[i]))
                if distanceSquaredToSegment(p, a, b) > r2 {
                    xs.append(splat.xs[i]); ys.append(splat.ys[i])
                    rs.append(splat.rs[i]); alphas.append(splat.alphas[i])
                }
            }
            if !xs.isEmpty {
                result.append(SpraySplat(style: splat.style, color: splat.color,
                                         xs: xs, ys: ys, rs: rs, alphas: alphas))
            }
        }
        return result
    }

    private static func distanceSquaredToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 1e-6 else { let ex = p.x - a.x, ey = p.y - a.y; return ex * ex + ey * ey }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = max(0, min(1, t))
        let ex = p.x - (a.x + t * dx), ey = p.y - (a.y + t * dy)
        return ex * ex + ey * ey
    }

    /// Draws splats into `ctx`. `map` converts a content point to target space, `scale`
    /// converts a content radius, `clip` (target space) culls offscreen particles.
    static func draw(_ splats: [SpraySplat], in ctx: CGContext,
                     scale: CGFloat, clip: CGRect?, map: (Float, Float) -> CGPoint) {
        let space = CGColorSpaceCreateDeviceRGB()
        for splat in splats {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            splat.color.uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            if splat.effectiveStyle == .airbrush {
                // Soft radial-gradient discs (full → transparent) scaled by per-dab alpha.
                let grad = CGGradient(colorsSpace: space,
                                      colors: [UIColor(red: r, green: g, blue: b, alpha: 1).cgColor,
                                               UIColor(red: r, green: g, blue: b, alpha: 0).cgColor] as CFArray,
                                      locations: [0, 1])
                for i in 0..<splat.count {
                    let c = map(splat.xs[i], splat.ys[i])
                    let rr = max(CGFloat(splat.rs[i]) * scale, 0.6)
                    if let clip, !clip.insetBy(dx: -rr - 2, dy: -rr - 2).contains(c) { continue }
                    guard let grad else { continue }
                    ctx.saveGState()
                    ctx.setAlpha(CGFloat(splat.alphas[i]) * a)
                    ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                           endCenter: c, endRadius: rr, options: [])
                    ctx.restoreGState()
                }
            } else {
                for i in 0..<splat.count {
                    let c = map(splat.xs[i], splat.ys[i])
                    let rr = max(CGFloat(splat.rs[i]) * scale, 0.4)
                    if let clip, !clip.insetBy(dx: -rr - 2, dy: -rr - 2).contains(c) { continue }
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: CGFloat(splat.alphas[i]) * a)
                    ctx.fillEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
                }
            }
        }
    }
}
