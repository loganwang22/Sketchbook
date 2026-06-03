import SwiftUI
import PencilKit
import GameController

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
    var photoScale: Double = 1
    var photoRotation: Double = 0
    var photoOffset: CGSize = .zero
    let onStrokeEnd: () -> Void
    let onCanvasReady: (PKCanvasView) -> Void
    var onPencilDoubleTap: () -> Void = {}
    var onStraightLineActiveChanged: (Bool) -> Void = { _ in }

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

        coord.lastStrokeCount = canvas.drawing.strokes.count
        coord.startObservingKeyboard()
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

        // Straight-line support: Shift = horizontal/vertical, Control = any angle.
        var lastStrokeCount = 0
        private var shiftHeld = false
        private var controlHeld = false
        private var isStraightening = false
        private var keyboardObserver: NSObjectProtocol?

        init(_ parent: PencilCanvas) { self.parent = parent }

        deinit {
            if let keyboardObserver { NotificationCenter.default.removeObserver(keyboardObserver) }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingInitialDrawing else { return }
            // Snap a freshly-finished stroke to a straight line when a modifier is held:
            // Shift -> horizontal/vertical, Control -> any angle. The guard + count check
            // prevents the replacement (which re-fires this delegate) from looping.
            if (shiftHeld || controlHeld), !isStraightening,
               canvasView.drawing.strokes.count == lastStrokeCount + 1 {
                isStraightening = true
                straightenLastStroke(canvasView, axisAligned: shiftHeld)
                isStraightening = false
            }
            lastStrokeCount = canvasView.drawing.strokes.count
            parent.drawingData = canvasView.drawing.dataRepresentation()
            parent.onStrokeEnd()
        }

        /// Replaces the last stroke with a clean straight line from its start to its end.
        /// `axisAligned` snaps to horizontal/vertical; otherwise the actual end is kept
        /// for a free-angle line.
        private func straightenLastStroke(_ canvas: PKCanvasView, axisAligned: Bool) {
            var strokes = canvas.drawing.strokes
            guard let last = strokes.last, last.path.count >= 2 else { return }
            let path = last.path
            let startPoint = path[0]
            let a = startPoint.location
            let b = path[path.count - 1].location
            let end: CGPoint
            if axisAligned {
                end = abs(b.x - a.x) >= abs(b.y - a.y)
                    ? CGPoint(x: b.x, y: a.y)   // horizontal
                    : CGPoint(x: a.x, y: b.y)   // vertical
            } else {
                end = b                          // any angle
            }
            let length = hypot(end.x - a.x, end.y - a.y)
            guard length > 1 else { return }
            let steps = max(2, Int(length / 4))
            var points: [PKStrokePoint] = []
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let loc = CGPoint(x: a.x + (end.x - a.x) * t, y: a.y + (end.y - a.y) * t)
                points.append(PKStrokePoint(location: loc,
                                            timeOffset: startPoint.timeOffset,
                                            size: startPoint.size,
                                            opacity: startPoint.opacity,
                                            force: startPoint.force,
                                            azimuth: startPoint.azimuth,
                                            altitude: startPoint.altitude))
            }
            let newPath = PKStrokePath(controlPoints: points, creationDate: Date())
            strokes[strokes.count - 1] = PKStroke(ink: last.ink, path: newPath)
            canvas.drawing = PKDrawing(strokes: strokes)
        }

        // MARK: hardware keyboard (Shift) tracking

        func startObservingKeyboard() {
            attachKeyboard(GCKeyboard.coalesced)
            keyboardObserver = NotificationCenter.default.addObserver(
                forName: .GCKeyboardDidConnect, object: nil, queue: .main
            ) { [weak self] note in
                self?.attachKeyboard(note.object as? GCKeyboard)
            }
        }

        private func attachKeyboard(_ keyboard: GCKeyboard?) {
            guard let input = keyboard?.keyboardInput else { return }
            let handler: GCControllerButtonValueChangedHandler = { [weak self, weak input] _, _, _ in
                guard let self, let input else { return }
                let shift = (input.button(forKeyCode: .leftShift)?.isPressed ?? false)
                         || (input.button(forKeyCode: .rightShift)?.isPressed ?? false)
                let control = (input.button(forKeyCode: .leftControl)?.isPressed ?? false)
                            || (input.button(forKeyCode: .rightControl)?.isPressed ?? false)
                DispatchQueue.main.async {
                    let wasActive = self.shiftHeld || self.controlHeld
                    self.shiftHeld = shift
                    self.controlHeld = control
                    let isActive = shift || control
                    if isActive != wasActive {
                        self.parent.onStraightLineActiveChanged(isActive)
                    }
                }
            }
            for code: GCKeyCode in [.leftShift, .rightShift, .leftControl, .rightControl] {
                input.button(forKeyCode: code)?.pressedChangedHandler = handler
            }
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
            // Map the photo's content rect (plus the user's edit offset) to the screen,
            // then apply scale + rotation about its centre. Everything is multiplied by
            // the zoom so the photo stays locked to the strokes.
            photoView.bounds = CGRect(origin: .zero, size: photoContentRect.size)
            let cx = photoContentRect.midX + parent.photoOffset.width
            let cy = photoContentRect.midY + parent.photoOffset.height
            photoView.center = CGPoint(x: cx * z - off.x, y: cy * z - off.y)
            photoView.transform = CGAffineTransform(rotationAngle: parent.photoRotation)
                .scaledBy(x: parent.photoScale * z, y: parent.photoScale * z)
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
