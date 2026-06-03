import UIKit
import PencilKit

enum ThumbnailRenderer {
    static let defaultSize = CGSize(width: 400, height: 300)

    /// Composites a drawing into a flat image. Layer order mirrors the live canvas:
    /// - trace: faint contour(s) *below* the strokes
    /// - colour: bold contour(s) *on top*
    /// Both contours are transparent except for the lines, so the paper colour shows.
    /// Reference photos are a side aid, not part of the artwork, so they're omitted.
    /// `photoImages` is keyed by `PhotoLayer.imageFilename`.
    static func render(drawing: Drawing,
                       photoImages: [String: UIImage],
                       canvasSize: CGSize = defaultSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let bounds = CGRect(origin: .zero, size: canvasSize)
        return renderer.image { ctx in
            drawing.backgroundColor.uiColor.setFill()
            ctx.fill(bounds)

            for layer in drawing.photoLayers where layer.mode == .trace {
                guard let photo = photoImages[layer.imageFilename] else { continue }
                photo.draw(in: aspectFit(photo.size, into: bounds),
                           blendMode: .normal, alpha: CGFloat(layer.opacity))
            }

            if !drawing.pkDrawingData.isEmpty,
               let pk = try? PKDrawing(data: drawing.pkDrawingData), !pk.bounds.isNull {
                let strokes = pk.image(from: pk.bounds, scale: UIScreen.main.scale)
                strokes.draw(in: aspectFit(strokes.size, into: bounds))
            }

            for layer in drawing.photoLayers where layer.mode == .coloringPage {
                guard let photo = photoImages[layer.imageFilename] else { continue }
                photo.draw(in: aspectFit(photo.size, into: bounds),
                           blendMode: .normal, alpha: 1.0)
            }
        }
    }

    /// Centered rect that fits `size` inside `rect` while preserving aspect ratio.
    private static func aspectFit(_ size: CGSize, into rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let w = size.width * scale, h = size.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
