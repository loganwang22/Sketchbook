import SwiftUI
import PencilKit
import GameController

/// One photo placed on the canvas. Identified by `id` so its image view persists across
/// updates; positioned in canvas content space so it tracks zoom/pan with the strokes.
struct ArtboardPhoto {
    let id: UUID
    let image: UIImage
    let mode: PhotoLayer.Mode   // .trace (below strokes) or .coloringPage (above)
    let opacity: Double
    let scale: Double
    let rotation: Double
    let offset: CGSize
    let hidden: Bool
}

/// The drawing surface. A `PKCanvasView` (the scroller) plus any number of photo layers
/// that live *in canvas content space* so they pan and zoom with the strokes.
struct PencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    let tool: PKTool
    let allowFingerDrawing: Bool
    var photos: [ArtboardPhoto] = []
    var showGrid: Bool = false
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

        container.addSubview(canvas)
        canvas.frame = container.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        container.addInteraction(pencilInteraction)

        let coord = context.coordinator
        coord.canvas = canvas
        coord.container = container
        container.onLayout = { [weak coord] in coord?.syncPhotos() }

        coord.lastStrokeCount = canvas.drawing.strokes.count
        coord.startObservingKeyboard()
        coord.applyPhotos(photos)
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
        coord.applyPhotos(photos)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: PencilCanvas
        weak var canvas: PKCanvasView?
        weak var container: ArtboardContainer?

        // One image view + captured content rect per photo id.
        private var photoViews: [UUID: UIImageView] = [:]
        private var photoRects: [UUID: CGRect] = [:]
        private var photoParams: [UUID: ArtboardPhoto] = [:]
        private weak var gridView: MiziGridView?
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

        func scrollViewDidScroll(_ scrollView: UIScrollView) { syncPhotos() }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { syncPhotos() }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.onPencilDoubleTap()
        }

        // MARK: photo layers

        func applyPhotos(_ photos: [ArtboardPhoto]) {
            guard let container, let canvas else { return }

            // 米字格 practice grid (Chinese writing mode), sits behind everything.
            if parent.showGrid, gridView == nil {
                let grid = MiziGridView()
                grid.isUserInteractionEnabled = false
                grid.backgroundColor = .clear
                grid.contentMode = .redraw
                grid.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                grid.frame = container.bounds
                gridView = grid
                container.addSubview(grid)
            } else if !parent.showGrid {
                gridView?.removeFromSuperview()
                gridView = nil
            }

            let ids = Set(photos.map(\.id))

            // Drop views for layers that no longer exist.
            for (id, view) in photoViews where !ids.contains(id) {
                view.removeFromSuperview()
                photoViews[id] = nil
                photoRects[id] = nil
                photoParams[id] = nil
            }

            // Create or update a view per layer.
            for photo in photos {
                let view: UIImageView
                if let existing = photoViews[photo.id] {
                    view = existing
                } else {
                    view = UIImageView()
                    view.contentMode = .scaleAspectFit
                    view.isUserInteractionEnabled = false
                    photoViews[photo.id] = view
                    container.addSubview(view)
                    capturePhotoRect(for: photo.id)   // land filling the current viewport
                }
                view.image = photo.image
                view.alpha = CGFloat(photo.opacity)
                view.isHidden = photo.hidden
                photoParams[photo.id] = photo
            }

            // Z-order, bottom to top: grid, trace layers, the canvas, colour layers.
            var ordered: [UIView] = []
            if let gridView { ordered.append(gridView) }
            ordered += photos.filter { $0.mode == .trace }.compactMap { photoViews[$0.id] }
            ordered.append(canvas)
            ordered += photos.filter { $0.mode == .coloringPage }.compactMap { photoViews[$0.id] }
            for (index, view) in ordered.enumerated() {
                container.insertSubview(view, at: index)
            }

            syncPhotos()
        }

        /// Records the currently-visible content rect so a new photo "lands" filling the
        /// screen wherever the child happens to be on the big canvas.
        private func capturePhotoRect(for id: UUID) {
            guard let canvas else { return }
            let z = max(canvas.zoomScale, 0.0001)
            let off = canvas.contentOffset
            let size = canvas.bounds.size
            guard size.width > 0 else { return }
            photoRects[id] = CGRect(x: off.x / z, y: off.y / z,
                                    width: size.width / z, height: size.height / z)
        }

        func syncPhotos() {
            guard let canvas else { return }
            let z = canvas.zoomScale
            let off = canvas.contentOffset
            if let gridView, let container {
                gridView.frame = container.bounds
                gridView.update(zoom: z, offset: off)
            }
            for (id, view) in photoViews {
                if photoRects[id] == nil { capturePhotoRect(for: id) }
                guard let rect = photoRects[id], let p = photoParams[id], rect != .zero else { continue }
                view.bounds = CGRect(origin: .zero, size: rect.size)
                let cx = rect.midX + p.offset.width
                let cy = rect.midY + p.offset.height
                view.center = CGPoint(x: cx * z - off.x, y: cy * z - off.y)
                view.transform = CGAffineTransform(rotationAngle: p.rotation)
                    .scaledBy(x: p.scale * z, y: p.scale * z)
            }
        }

        // MARK: straight lines

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

        // MARK: hardware keyboard (Shift / Control) tracking

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
    }
}

/// Plain container that reports layout passes so the photo layers can be repositioned.
final class ArtboardContainer: UIView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

/// Draws an "infinite" 米字格 (rice-grid) practice grid, aligned to canvas content space
/// so the cells stay put under the writing as the child zooms/pans. Solid red cell
/// borders with dashed centre cross + diagonals, the traditional handwriting guide.
final class MiziGridView: UIView {
    private var zoom: CGFloat = 1
    private var offset: CGPoint = .zero
    private let baseCell: CGFloat = 230   // content-space points per character cell

    func update(zoom: CGFloat, offset: CGPoint) {
        self.zoom = zoom
        self.offset = offset
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let cell = baseCell * zoom
        guard cell > 8 else { return }

        let kx0 = Int(floor(offset.x / cell)), kx1 = Int(ceil((offset.x + bounds.width) / cell))
        let ky0 = Int(floor(offset.y / cell)), ky1 = Int(ceil((offset.y + bounds.height) / cell))
        guard kx1 >= kx0, ky1 >= ky0 else { return }

        // Solid cell borders.
        ctx.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [])
        for k in kx0...kx1 {
            let x = CGFloat(k) * cell - offset.x
            ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        for k in ky0...ky1 {
            let y = CGFloat(k) * cell - offset.y
            ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        ctx.strokePath()

        // Dashed centre cross + diagonals inside each cell.
        ctx.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.3).cgColor)
        ctx.setLineDash(phase: 0, lengths: [5, 4])
        for kx in kx0..<max(kx1, kx0 + 1) {
            for ky in ky0..<max(ky1, ky0 + 1) {
                let x0 = CGFloat(kx) * cell - offset.x
                let y0 = CGFloat(ky) * cell - offset.y
                let mx = x0 + cell / 2, my = y0 + cell / 2
                ctx.move(to: CGPoint(x: mx, y: y0)); ctx.addLine(to: CGPoint(x: mx, y: y0 + cell))
                ctx.move(to: CGPoint(x: x0, y: my)); ctx.addLine(to: CGPoint(x: x0 + cell, y: my))
                ctx.move(to: CGPoint(x: x0, y: y0)); ctx.addLine(to: CGPoint(x: x0 + cell, y: y0 + cell))
                ctx.move(to: CGPoint(x: x0 + cell, y: y0)); ctx.addLine(to: CGPoint(x: x0, y: y0 + cell))
            }
        }
        ctx.strokePath()
    }
}
