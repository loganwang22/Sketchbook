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

            // Chinese writing: grid and strokes share one content-space mapping so they
            // line up (the previous ad-hoc grid didn't match the strokes at all).
            if drawing.kind == .chineseWriting {
                drawChinesePage(drawing, in: bounds, context: ctx.cgContext)
                return
            }

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

    /// Renders the 米字格 grid and the strokes through a single content→thumbnail
    /// transform, so the grid cells sit under the writing exactly as on the live canvas.
    private static func drawChinesePage(_ drawing: Drawing, in bounds: CGRect, context ctx: CGContext) {
        let cell = MiziGrid.cellSize
        let pk = drawing.pkDrawingData.isEmpty ? nil : try? PKDrawing(data: drawing.pkDrawingData)

        // The content region to show: the strokes' cells plus a margin, or a default
        // few-cell page when empty.
        let content: CGRect
        if let pk, !pk.bounds.isNull {
            let b = pk.bounds
            let x0 = (floor(b.minX / cell) - 0.5) * cell
            let y0 = (floor(b.minY / cell) - 0.5) * cell
            let x1 = (ceil(b.maxX / cell) + 0.5) * cell
            let y1 = (ceil(b.maxY / cell) + 0.5) * cell
            content = CGRect(x: x0, y: y0, width: max(x1 - x0, cell), height: max(y1 - y0, cell))
        } else {
            content = CGRect(x: 0, y: 0, width: cell * 4, height: cell * 3)
        }

        let fit = min(bounds.width / content.width, bounds.height / content.height)
        let drawW = content.width * fit, drawH = content.height * fit
        let drawRect = CGRect(x: bounds.midX - drawW / 2, y: bounds.midY - drawH / 2,
                              width: drawW, height: drawH)
        func mapX(_ x: CGFloat) -> CGFloat { drawRect.minX + (x - content.minX) * fit }
        func mapY(_ y: CGFloat) -> CGFloat { drawRect.minY + (y - content.minY) * fit }

        ctx.saveGState()
        ctx.clip(to: drawRect)

        // Solid cell borders.
        ctx.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(1)
        let kx0 = Int(floor(content.minX / cell)), kx1 = Int(ceil(content.maxX / cell))
        let ky0 = Int(floor(content.minY / cell)), ky1 = Int(ceil(content.maxY / cell))
        for k in kx0...kx1 {
            let x = mapX(CGFloat(k) * cell)
            ctx.move(to: CGPoint(x: x, y: drawRect.minY)); ctx.addLine(to: CGPoint(x: x, y: drawRect.maxY))
        }
        for k in ky0...ky1 {
            let y = mapY(CGFloat(k) * cell)
            ctx.move(to: CGPoint(x: drawRect.minX, y: y)); ctx.addLine(to: CGPoint(x: drawRect.maxX, y: y))
        }
        ctx.strokePath()

        // Dashed centre cross + diagonals per cell.
        ctx.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.3).cgColor)
        ctx.setLineDash(phase: 0, lengths: [4, 3])
        for kx in kx0..<max(kx1, kx0 + 1) {
            for ky in ky0..<max(ky1, ky0 + 1) {
                let lx = mapX(CGFloat(kx) * cell), rx = mapX(CGFloat(kx + 1) * cell)
                let ty = mapY(CGFloat(ky) * cell), by = mapY(CGFloat(ky + 1) * cell)
                let mx = (lx + rx) / 2, my = (ty + by) / 2
                ctx.move(to: CGPoint(x: mx, y: ty)); ctx.addLine(to: CGPoint(x: mx, y: by))
                ctx.move(to: CGPoint(x: lx, y: my)); ctx.addLine(to: CGPoint(x: rx, y: my))
                ctx.move(to: CGPoint(x: lx, y: ty)); ctx.addLine(to: CGPoint(x: rx, y: by))
                ctx.move(to: CGPoint(x: rx, y: ty)); ctx.addLine(to: CGPoint(x: lx, y: by))
            }
        }
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // Strokes on top, mapped through the same content rect so they sit in the cells.
        if let pk, !pk.bounds.isNull {
            let strokes = pk.image(from: content, scale: UIScreen.main.scale)
            strokes.draw(in: drawRect)
        }
        ctx.restoreGState()
    }

    /// Centered rect that fits `size` inside `rect` while preserving aspect ratio.
    private static func aspectFit(_ size: CGSize, into rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let w = size.width * scale, h = size.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
