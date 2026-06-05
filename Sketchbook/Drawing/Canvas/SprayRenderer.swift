import UIKit
import CoreGraphics

/// Generates and draws custom spray-paint particles. Spray is the app's own brush —
/// PencilKit has no airbrush ink and can't render the fine dots a spray needs.
enum SprayRenderer {

    /// Appends a cone of fine particles for the segment a→b (content space) to `splat`,
    /// in real time as the pencil moves. Dense near the path, sparse at the edges.
    static func scatter(into splat: inout SpraySplat, from a: CGPoint, to b: CGPoint, nozzle: CGFloat) {
        let spread = max(nozzle * 4, 16)
        let spacing = max(spread * 0.13, 2.5)   // tighter samples = denser spray
        let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y) / spacing))
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps)
            let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            for _ in 0..<7 {
                let off = (CGFloat.random(in: -1...1) + CGFloat.random(in: -1...1)) / 2
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let dist = off * spread
                splat.xs.append(Float(c.x + cos(angle) * dist))
                splat.ys.append(Float(c.y + sin(angle) * dist))
                splat.rs.append(Float.random(in: 0.8...2.4))
                splat.alphas.append(Float.random(in: 0.35...0.9))
            }
        }
    }

    /// Removes spray particles within `radius` of the segment a→b. Splats emptied out are
    /// dropped. Used by the eraser.
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
                result.append(SpraySplat(color: splat.color, xs: xs, ys: ys, rs: rs, alphas: alphas))
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

    /// Draws splats into `ctx`. `map` converts a content-space point to the target space
    /// and `scale` converts a content-space radius; `clip` (target space) culls offscreen
    /// particles. Used by the live canvas overlay and the gallery thumbnail.
    static func draw(_ splats: [SpraySplat], in ctx: CGContext,
                     scale: CGFloat, clip: CGRect?, map: (Float, Float) -> CGPoint) {
        for splat in splats {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            splat.color.uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
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
