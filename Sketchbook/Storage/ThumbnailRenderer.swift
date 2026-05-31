import UIKit
import PencilKit

enum ThumbnailRenderer {
    static let defaultSize = CGSize(width: 400, height: 300)

    static func render(drawing: Drawing,
                       photoImage: UIImage?,
                       canvasSize: CGSize = defaultSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            // 1. background fill
            drawing.backgroundColor.uiColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            // 2. photo layer (if any)
            if let photo = photoImage, let layer = drawing.photoLayer {
                ctx.cgContext.saveGState()
                ctx.cgContext.setAlpha(CGFloat(layer.opacity))
                ctx.cgContext.concatenate(layer.transform)
                photo.draw(in: CGRect(origin: .zero, size: canvasSize))
                ctx.cgContext.restoreGState()
            }

            // 3. PKDrawing strokes
            if !drawing.pkDrawingData.isEmpty,
               let pk = try? PKDrawing(data: drawing.pkDrawingData) {
                let pkImage = pk.image(from: pk.bounds, scale: UIScreen.main.scale)
                pkImage.draw(in: CGRect(origin: .zero, size: canvasSize))
            }
        }
    }
}
