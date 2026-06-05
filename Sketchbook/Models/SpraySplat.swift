import Foundation
import CoreGraphics

/// One spray-paint stroke: a cloud of fine particles in canvas content space, all one
/// colour. Stored as parallel arrays of Floats so the JSON stays compact.
///
/// Spray is rendered by the app itself (Core Graphics), not by PencilKit — PencilKit has
/// no airbrush ink and can't render the fine dots a spray needs.
struct SpraySplat: Codable, Equatable {
    /// How the particles are rendered. Optional so splats saved before styles existed
    /// decode as `.spray`.
    enum Style: String, Codable { case spray, airbrush, oil }
    var style: Style?
    var color: ColorRGBA
    var xs: [Float]      // particle centre x (content space)
    var ys: [Float]      // particle centre y (content space)
    var rs: [Float]      // particle radius
    var alphas: [Float]  // particle opacity
    /// Oil only: per-dab orientation (radians) and brightness offset, giving Van Gogh
    /// directional impasto streaks with value variation. Nil for spray/airbrush.
    var dirs: [Float]? = nil
    var vs: [Float]? = nil

    var effectiveStyle: Style { style ?? .spray }
    var count: Int { min(xs.count, ys.count, rs.count, alphas.count) }

    /// The content-space bounding box of all particles (for thumbnail framing). Oil dabs
    /// are elongated, so their extent is widened.
    var bounds: CGRect? {
        guard count > 0 else { return nil }
        let stretch: Float = effectiveStyle == .oil ? 2.6 : 1
        var minX = Float.greatestFiniteMagnitude, minY = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for i in 0..<count {
            let e = rs[i] * stretch
            minX = min(minX, xs[i] - e); maxX = max(maxX, xs[i] + e)
            minY = min(minY, ys[i] - e); maxY = max(maxY, ys[i] + e)
        }
        return CGRect(x: CGFloat(minX), y: CGFloat(minY),
                      width: CGFloat(maxX - minX), height: CGFloat(maxY - minY))
    }
}
