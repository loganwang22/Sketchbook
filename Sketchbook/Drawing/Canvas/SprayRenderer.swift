import UIKit
import CoreGraphics

/// Generates and draws custom spray-paint particles. Spray is the app's own brush —
/// PencilKit has no airbrush ink and can't render the fine dots a spray needs.
enum SprayRenderer {

    /// Builds a spray splat from the path the child drew (points in content space).
    /// Particles scatter in a cone along the path: dense near it, sparse at the edges.
    static func makeSplat(points: [CGPoint], nozzle: CGFloat, color: ColorRGBA) -> SpraySplat {
        let spread = max(nozzle * 4, 16)            // how far paint flies from the path
        let spacing = max(spread * 0.22, 4)         // sample step along the path
        let perSample = 6
        let maxDots = 600

        var samples: [CGPoint] = []
        if points.count <= 1 {
            samples = points
        } else {
            for i in 0..<(points.count - 1) {
                let a = points[i], b = points[i + 1]
                let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y) / spacing))
                for s in 0..<steps {
                    let t = CGFloat(s) / CGFloat(steps)
                    samples.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                }
            }
            samples.append(points[points.count - 1])
        }

        var xs: [Float] = [], ys: [Float] = [], rs: [Float] = [], alphas: [Float] = []
        outer: for c in samples {
            for _ in 0..<perSample {
                // Sum of two uniforms ≈ triangular falloff (denser toward the path).
                let off = (CGFloat.random(in: -1...1) + CGFloat.random(in: -1...1)) / 2
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let dist = off * spread
                xs.append(Float(c.x + cos(angle) * dist))
                ys.append(Float(c.y + sin(angle) * dist))
                rs.append(Float.random(in: 0.8...2.4))
                alphas.append(Float.random(in: 0.35...0.9))
                if xs.count >= maxDots { break outer }
            }
        }
        return SpraySplat(color: color, xs: xs, ys: ys, rs: rs, alphas: alphas)
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
