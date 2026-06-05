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
        /// Spread particles evenly over the disc (no dense centre line) vs. clustered near
        /// the path. Airbrush uses even spread so it leaves no visible stroke trace.
        var evenSpread: Bool = false
    }
    private static func params(_ style: SpraySplat.Style, nozzle: CGFloat) -> Params {
        switch style {
        case .spray:    // fine hard speckles flung wide
            return Params(spread: max(nozzle * 4, 16), spacing: max(nozzle * 0.5, 2.5), perSample: 7,
                          rMin: 0.8, rMax: 2.4, aMin: 0.35, aMax: 0.9)
        case .airbrush: // a wide, even cloud — no stroke trace, but lays down real paint
            return Params(spread: max(nozzle * 2.8, 20), spacing: max(nozzle * 0.4, 3), perSample: 16,
                          rMin: nozzle * 0.28, rMax: nozzle * 0.62, aMin: 0.06, aMax: 0.16,
                          evenSpread: true)
        case .oil:      // spaced, elongated, opaque dabs → Van Gogh directional impasto
            return Params(spread: max(nozzle * 0.3, 2), spacing: max(nozzle * 0.55, 3), perSample: 2,
                          rMin: nozzle * 0.22, rMax: nozzle * 0.42, aMin: 0.92, aMax: 1.0)
        }
    }

    /// Appends particles for the segment a→b (content space) to `splat` in real time.
    static func scatter(into splat: inout SpraySplat, from a: CGPoint, to b: CGPoint,
                        nozzle: CGFloat, style: SpraySplat.Style) {
        let p = params(style, nozzle: nozzle)
        let segAngle = (a == b) ? 0 : atan2(b.y - a.y, b.x - a.x)   // oil dabs follow the stroke
        let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y) / p.spacing))
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps)
            let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            for _ in 0..<p.perSample {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                // evenSpread: sqrt → uniform over the disc (no hot centre, no trace).
                // otherwise: sum-of-two-uniforms → clustered near the path.
                let dist = p.evenSpread
                    ? p.spread * sqrt(CGFloat.random(in: 0...1))
                    : (CGFloat.random(in: -1...1) + CGFloat.random(in: -1...1)) / 2 * p.spread
                splat.xs.append(Float(c.x + cos(angle) * dist))
                splat.ys.append(Float(c.y + sin(angle) * dist))
                splat.rs.append(Float(CGFloat.random(in: p.rMin...max(p.rMin, p.rMax))))
                splat.alphas.append(Float(CGFloat.random(in: p.aMin...p.aMax)))
                // Oil dabs carry direction (along the stroke, jittered) + a brightness
                // offset so they read as separate, ridged Van Gogh strokes.
                splat.dirs?.append(Float(segAngle + CGFloat.random(in: -0.32...0.32)))
                splat.vs?.append(Float.random(in: -0.22...0.22))
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
            var dirs: [Float]? = splat.dirs == nil ? nil : []
            var vs: [Float]? = splat.vs == nil ? nil : []
            for i in 0..<splat.count {
                let p = CGPoint(x: CGFloat(splat.xs[i]), y: CGFloat(splat.ys[i]))
                if distanceSquaredToSegment(p, a, b) > r2 {
                    xs.append(splat.xs[i]); ys.append(splat.ys[i])
                    rs.append(splat.rs[i]); alphas.append(splat.alphas[i])
                    if let d = splat.dirs, i < d.count { dirs?.append(d[i]) }
                    if let val = splat.vs, i < val.count { vs?.append(val[i]) }
                }
            }
            if !xs.isEmpty {
                result.append(SpraySplat(style: splat.style, color: splat.color,
                                         xs: xs, ys: ys, rs: rs, alphas: alphas, dirs: dirs, vs: vs))
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
            if splat.effectiveStyle == .oil {
                // Elongated, rotated, value-varied dabs → directional impasto ridges.
                for i in 0..<splat.count {
                    let c = map(splat.xs[i], splat.ys[i])
                    let rr = max(CGFloat(splat.rs[i]) * scale, 0.6)
                    if let clip, !clip.insetBy(dx: -rr * 3 - 2, dy: -rr * 3 - 2).contains(c) { continue }
                    let dir = CGFloat(i < (splat.dirs?.count ?? 0) ? splat.dirs![i] : 0)
                    let v = CGFloat(i < (splat.vs?.count ?? 0) ? splat.vs![i] : 0)
                    ctx.saveGState()
                    ctx.translateBy(x: c.x, y: c.y)
                    ctx.rotate(by: dir)
                    ctx.setFillColor(red: min(max(r + v, 0), 1), green: min(max(g + v, 0), 1),
                                     blue: min(max(b + v, 0), 1), alpha: CGFloat(splat.alphas[i]) * a)
                    let halfLen = rr * 2.4, halfTh = rr      // ~2.4:1 elongated dab
                    ctx.fillEllipse(in: CGRect(x: -halfLen, y: -halfTh, width: halfLen * 2, height: halfTh * 2))
                    ctx.restoreGState()
                }
            } else if splat.effectiveStyle == .airbrush {
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
