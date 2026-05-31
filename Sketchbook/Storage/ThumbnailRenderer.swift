import UIKit
import PencilKit

enum ThumbnailRenderer {
    static let defaultSize = CGSize(width: 400, height: 300)

    /// Composites a drawing into a flat image. Layer order mirrors the live canvas:
    /// - trace: faint photo *below* the strokes
    /// - colour: black line-art *on top* (multiply, so white reads as transparent)
    /// - reference: photo is a side aid, not part of the artwork, so it's omitted
    static func render(drawing: Drawing,
                       photoImage: UIImage?,
                       canvasSize: CGSize = defaultSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let bounds = CGRect(origin: .zero, size: canvasSize)
        let mode = drawing.photoLayer?.mode
        return renderer.image { ctx in
            drawing.backgroundColor.uiColor.setFill()
            ctx.fill(bounds)

            if mode == .trace, let photo = photoImage {
                photo.draw(in: aspectFit(photo.size, into: bounds),
                           blendMode: .normal,
                           alpha: CGFloat(drawing.photoLayer?.opacity ?? 0.35))
            }

            if !drawing.pkDrawingData.isEmpty,
               let pk = try? PKDrawing(data: drawing.pkDrawingData), !pk.bounds.isNull {
                let strokes = pk.image(from: pk.bounds, scale: UIScreen.main.scale)
                strokes.draw(in: aspectFit(strokes.size, into: bounds))
            }

            if mode == .coloringPage, let photo = photoImage {
                photo.draw(in: aspectFit(photo.size, into: bounds),
                           blendMode: .multiply,
                           alpha: 1.0)
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
