import Foundation
import CoreGraphics

/// One spray-paint stroke: a cloud of fine particles in canvas content space, all one
/// colour. Stored as parallel arrays of Floats so the JSON stays compact.
///
/// Spray is rendered by the app itself (Core Graphics), not by PencilKit — PencilKit has
/// no airbrush ink and can't render the fine dots a spray needs.
struct SpraySplat: Codable, Equatable {
    var color: ColorRGBA
    var xs: [Float]      // particle centre x (content space)
    var ys: [Float]      // particle centre y (content space)
    var rs: [Float]      // particle radius
    var alphas: [Float]  // particle opacity

    var count: Int { min(xs.count, ys.count, rs.count, alphas.count) }

    /// The content-space bounding box of all particles (for thumbnail framing).
    var bounds: CGRect? {
        guard count > 0 else { return nil }
        var minX = Float.greatestFiniteMagnitude, minY = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for i in 0..<count {
            minX = min(minX, xs[i] - rs[i]); maxX = max(maxX, xs[i] + rs[i])
            minY = min(minY, ys[i] - rs[i]); maxY = max(maxY, ys[i] + rs[i])
        }
        return CGRect(x: CGFloat(minX), y: CGFloat(minY),
                      width: CGFloat(maxX - minX), height: CGFloat(maxY - minY))
    }
}
