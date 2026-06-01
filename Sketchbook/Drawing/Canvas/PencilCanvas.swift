import SwiftUI
import PencilKit

/// The drawing surface. A `PKCanvasView` (the scroller) plus an optional photo layer
/// that lives *in canvas content space* — it pans and zooms with the strokes, so a
/// traced or coloured photo stays aligned no matter how the child zooms.
struct PencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    let tool: PKTool
    let allowFingerDrawing: Bool
    var photoImage: UIImage? = nil
    var photoHidden: Bool = false
    var photoMode: PhotoLayer.Mode? = nil
    var photoOpacity: Double = 1.0
    let onStrokeEnd: () -> Void
    let onCanvasReady: (PKCanvasView) -> Void
    var onPencilDoubleTap: () -> Void = {}

    func makeUIView(context: Context) -> ArtboardContainer {
        let container = ArtboardContainer()
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.tool = tool
        canvas.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.minimumZoomScale = 0.25
        canvas.maximumZoomScale = 4.0
        canvas.contentSize = CGSize(width: 6000, height: 6000)
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = true
        // Loading a saved drawing can fire the change delegate; suppress that so
        // merely opening a painting isn't recorded as an edit (see #5 ordering).
        context.coordinator.isApplyingInitialDrawing = true
        if !drawingData.isEmpty, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        DispatchQueue.main.async { context.coordinator.isApplyingInitialDrawing = false }

        let photoView = UIImageView()
        photoView.contentMode = .scaleAspectFit
        photoView.isUserInteractionEnabled = false

        container.addSubview(photoView)
        container.addSubview(canvas)
        canvas.frame = container.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        container.addInteraction(pencilInteraction)

        let coord = context.coordinator
        coord.canvas = canvas
        coord.photoView = photoView
        coord.container = container
        container.onLayout = { [weak coord] in coord?.syncPhoto() }

        coord.applyPhoto(image: photoImage, hidden: photoHidden, mode: photoMode, opacity: photoOpacity)
        onCanvasReady(canvas)
        return container
    }

    func updateUIView(_ container: ArtboardContainer, context: Context) {
        let coord = context.coordinator
        coord.parent = self
        guard let canvas = coord.canvas else { return }
        canvas.tool = tool
        canvas.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        if drawingData.isEmpty && !canvas.drawing.strokes.isEmpty {
            canvas.drawing = PKDrawing()
        }
        coord.applyPhoto(image: photoImage, hidden: photoHidden, mode: photoMode, opacity: photoOpacity)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: PencilCanvas
        weak var canvas: PKCanvasView?
        weak var photoView: UIImageView?
        weak var container: ArtboardContainer?

        /// The photo's rectangle in canvas *content* coordinates, captured when the
        /// photo is first placed (it fills the viewport at that moment). syncPhoto then
        /// maps it through the live zoom + offset so it tracks the strokes.
        private var photoContentRect: CGRect = .zero
        private var currentImage: UIImage?
        var isApplyingInitialDrawing = false

        init(_ parent: PencilCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingInitialDrawing else { return }
            parent.drawingData = canvasView.drawing.dataRepresentation()
            parent.onStrokeEnd()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) { syncPhoto() }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { syncPhoto() }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.onPencilDoubleTap()
        }

        func applyPhoto(image: UIImage?, hidden: Bool, mode: PhotoLayer.Mode?, opacity: Double) {
            guard let photoView, let container else { return }
            if image !== currentImage {
                currentImage = image
                photoView.image = image
                if image != nil { capturePhotoRect() }
            }
            photoView.isHidden = (image == nil) || hidden
            photoView.alpha = CGFloat(opacity)
            // Colour: bold contour on top of the strokes. Trace: faint contour behind
            // them. The contour is transparent except for the lines, so the paper shows.
            if mode == .coloringPage {
                container.bringSubviewToFront(photoView)
            } else {
                container.sendSubviewToBack(photoView)
            }
            syncPhoto()
        }

        /// Records the currently-visible content rect so the photo "lands" filling the
        /// screen wherever the child happens to be on the big canvas.
        private func capturePhotoRect() {
            guard let canvas else { return }
            let z = max(canvas.zoomScale, 0.0001)
            let off = canvas.contentOffset
            let size = canvas.bounds.size
            guard size.width > 0 else { return }
            photoContentRect = CGRect(x: off.x / z, y: off.y / z,
                                      width: size.width / z, height: size.height / z)
        }

        func syncPhoto() {
            guard let canvas, let photoView, photoContentRect != .zero else { return }
            let z = canvas.zoomScale
            let off = canvas.contentOffset
            photoView.frame = CGRect(x: photoContentRect.minX * z - off.x,
                                     y: photoContentRect.minY * z - off.y,
                                     width: photoContentRect.width * z,
                                     height: photoContentRect.height * z)
        }
    }
}

/// Plain container that reports layout passes so the photo layer can be repositioned.
final class ArtboardContainer: UIView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
