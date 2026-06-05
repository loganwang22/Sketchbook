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
    var customBrushActive: Bool = false               // spray / airbrush / oil selected
    var customBrushStyle: SpraySplat.Style = .spray
    var eraserActive: Bool = false
    var spraySplats: [SpraySplat] = []
    var sprayRevision: Int = 0
    var sprayColor: ColorRGBA = ColorRGBA(r: 0, g: 0, b: 0)
    var eraserRadius: CGFloat = 30
    var initialZoom: CGFloat? = nil
    let onStrokeEnd: () -> Void
    let onCanvasReady: (PKCanvasView) -> Void
    var onPencilTap: () -> Void = {}
    var onStraightLineActiveChanged: (Bool) -> Void = { _ in }
    /// Called on lift with the full new splats array (spray added or erased) so the model
    /// can store it and register undo.
    var onSprayCommit: ([SpraySplat]) -> Void = { _ in }

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

        // Pencil-only recognizer that drives the custom spray brush and spray-erasing in
        // real time. Disabled for normal brushes, so it can't affect ordinary drawing.
        let sprayGR = UILongPressGestureRecognizer(target: context.coordinator,
                                                   action: #selector(Coordinator.handleSpray(_:)))
        sprayGR.minimumPressDuration = 0
        sprayGR.allowableMovement = .greatestFiniteMagnitude
        sprayGR.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        sprayGR.cancelsTouchesInView = false
        sprayGR.delegate = context.coordinator
        sprayGR.isEnabled = false
        container.addGestureRecognizer(sprayGR)

        let coord = context.coordinator
        coord.canvas = canvas
        coord.container = container
        coord.sprayGR = sprayGR
        container.onLayout = { [weak coord] in coord?.onContainerLayout() }

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
        // Spray captures the pencil itself; eraser lets PencilKit erase strokes while the
        // recognizer also removes spray. Both modes enable the recognizer; spray also
        // suppresses PencilKit's pen line so the pencil only sprays.
        // Custom brushes always need the recognizer; the eraser only needs it when there's
        // spray to remove (otherwise erasing stays purely PencilKit, untouched).
        coord.sprayGR?.isEnabled = customBrushActive || (eraserActive && !spraySplats.isEmpty)
        canvas.drawingGestureRecognizer.isEnabled = !customBrushActive
        coord.syncWorkingSplatsIfNeeded()
        coord.applyPhotos(photos)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate,
                             UIGestureRecognizerDelegate {
        var parent: PencilCanvas
        weak var canvas: PKCanvasView?
        weak var container: ArtboardContainer?

        // One image view + captured content rect per photo id.
        private var photoViews: [UUID: UIImageView] = [:]
        private var photoRects: [UUID: CGRect] = [:]
        private var photoParams: [UUID: ArtboardPhoto] = [:]
        private weak var gridView: MiziGridView?
        private weak var sprayLayer: SprayLayerView?        // draws the ACTIVE stroke only
        private weak var committedSprayView: UIImageView?   // settled spray, transform-tracked
        private var committedSprayBBox: CGRect = .null
        private var didApplyInitialZoom = false
        var isApplyingInitialDrawing = false

        // Spray brush state. `workingSplats` is the live copy; it syncs from the model
        // whenever `sprayRevision` changes (load / undo / clear).
        weak var sprayGR: UILongPressGestureRecognizer?
        private var workingSplats: [SpraySplat] = []
        private var liveSplat: SpraySplat?
        private var lastSprayPoint: CGPoint?
        private var lastSprayRevision = -1
        private var erasing = false
        private let maxLiveParticles = 12000

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

        func onContainerLayout() {
            applyInitialZoomIfNeeded()
            syncPhotos()
        }

        /// Chinese writing opens slightly zoomed out (a comfortable writing zoom).
        private func applyInitialZoomIfNeeded() {
            guard !didApplyInitialZoom, let zoom = parent.initialZoom,
                  let canvas, canvas.bounds.width > 0 else { return }
            canvas.setZoomScale(zoom, animated: false)
            canvas.setContentOffset(.zero, animated: false)
            didApplyInitialZoom = true
        }

        // Apple Pencil barrel gestures. The legacy `pencilInteractionDidTap` was
        // deprecated in iOS 17.5 and is no longer delivered on this OS, so we implement
        // the current delegate methods. There is no single-tap gesture in hardware:
        // double-tap (Pencil 2 / Pro) and squeeze (Pro only) are the only ones.
        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
            parent.onPencilTap()
        }

        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            guard squeeze.phase == .ended else { return }   // fire once, when the squeeze completes
            parent.onPencilTap()
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

            // Settled spray is a transform-tracked image (stays in sync with strokes on
            // zoom/pan, like photos); the draw-based layer renders only the active stroke.
            if committedSprayView == nil {
                let iv = UIImageView()
                iv.isUserInteractionEnabled = false
                iv.contentMode = .scaleToFill
                committedSprayView = iv
                container.addSubview(iv)
                rebuildCommittedSpray()
            }
            if sprayLayer == nil {
                let layer = SprayLayerView()
                layer.isUserInteractionEnabled = false
                layer.backgroundColor = .clear
                layer.contentMode = .redraw
                layer.frame = container.bounds
                sprayLayer = layer
                container.addSubview(layer)
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

            // Z-order, bottom to top: grid, trace layers, canvas, committed spray, the
            // active-stroke layer, colour layers.
            var ordered: [UIView] = []
            if let gridView { ordered.append(gridView) }
            ordered += photos.filter { $0.mode == .trace }.compactMap { photoViews[$0.id] }
            ordered.append(canvas)
            if let committedSprayView { ordered.append(committedSprayView) }
            if let sprayLayer { ordered.append(sprayLayer) }
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
            if let sprayLayer, let container {
                sprayLayer.frame = container.bounds
                sprayLayer.update(zoom: z, offset: off)
            }
            // Committed spray tracks zoom/pan by transform — frame-synced with the strokes.
            if let csv = committedSprayView, !committedSprayBBox.isNull, committedSprayBBox.width > 0 {
                csv.bounds = CGRect(origin: .zero, size: committedSprayBBox.size)
                csv.center = CGPoint(x: committedSprayBBox.midX * z - off.x,
                                     y: committedSprayBBox.midY * z - off.y)
                csv.transform = CGAffineTransform(scaleX: z, y: z)
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

        // MARK: spray (custom real-time brush)

        /// Pulls the latest spray from the model into the working copy when it changed
        /// outside a live stroke (open, undo/redo, clear), and rebuilds the settled image.
        func syncWorkingSplatsIfNeeded() {
            guard parent.sprayRevision != lastSprayRevision else { return }
            lastSprayRevision = parent.sprayRevision
            workingSplats = parent.spraySplats
            if !erasing && liveSplat == nil { rebuildCommittedSpray() }
        }

        /// Renders the working splats into the settled image and clears the active layer.
        private func rebuildCommittedSpray() {
            let (image, bbox) = SprayLayerView.renderImage(workingSplats)
            committedSprayBBox = bbox
            committedSprayView?.image = image
            committedSprayView?.isHidden = (image == nil)
            sprayLayer?.splats = []
            sprayLayer?.liveSplat = nil
            sprayLayer?.isHidden = true
            sprayLayer?.setNeedsDisplay()
            syncPhotos()
        }

        /// Two recognizers (PencilKit's eraser + ours) must work together so the eraser
        /// removes strokes and spray at once.
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        /// Real-time spray / spray-erase. The pencil is captured here (not by PencilKit),
        /// so paint appears as the child moves rather than after they lift.
        @objc func handleSpray(_ g: UILongPressGestureRecognizer) {
            guard let canvas, let container else { return }
            let z = canvas.zoomScale
            let off = canvas.contentOffset
            let loc = g.location(in: container)
            let point = CGPoint(x: (loc.x + off.x) / z, y: (loc.y + off.y) / z)  // -> content space

            switch g.state {
            case .began:
                canvas.panGestureRecognizer.isEnabled = false   // a resting palm shouldn't pan
                lastSprayPoint = point
                sprayLayer?.isHidden = false
                if parent.customBrushActive {
                    // Settled spray stays in its image; only the new stroke draws here.
                    liveSplat = SpraySplat(style: parent.customBrushStyle, color: parent.sprayColor,
                                           xs: [], ys: [], rs: [], alphas: [])
                    sprayLayer?.splats = []
                    stampSpray(from: point, to: point)
                } else if parent.eraserActive {
                    // Erasing edits existing spray, so show the working copy live.
                    erasing = true
                    committedSprayView?.isHidden = true
                    sprayLayer?.splats = workingSplats
                    sprayLayer?.liveSplat = nil
                    sprayLayer?.setNeedsDisplay()
                    eraseSpray(at: point)
                }
            case .changed:
                let from = lastSprayPoint ?? point
                if parent.customBrushActive {
                    stampSpray(from: from, to: point)
                } else if parent.eraserActive {
                    eraseSpray(from: from, to: point)
                }
                lastSprayPoint = point
            case .ended, .cancelled, .failed:
                canvas.panGestureRecognizer.isEnabled = true
                lastSprayPoint = nil
                if parent.customBrushActive, let live = liveSplat, live.count > 0 {
                    workingSplats.append(live)
                }
                liveSplat = nil
                erasing = false
                rebuildCommittedSpray()              // bake the stroke into the settled image
                parent.onSprayCommit(workingSplats)  // model + undo
            default:
                break
            }
        }

        private func stampSpray(from a: CGPoint, to b: CGPoint) {
            guard liveSplat != nil, liveSplat!.count < maxLiveParticles else { return }
            SprayRenderer.scatter(into: &liveSplat!, from: a, to: b,
                                  nozzle: sprayNozzle, style: liveSplat!.effectiveStyle)
            sprayLayer?.liveSplat = liveSplat
            // Redraw just the affected band.
            sprayLayer?.setNeedsDisplay(dirtyRect(a, b, pad: sprayNozzle * 4 + 6))
        }

        /// Spray nozzle width in content space (drives scatter spread). Mirrors BrushKind.
        private var sprayNozzle: CGFloat {
            (parent.tool as? PKInkingTool).map { CGFloat($0.width) } ?? 10
        }

        private func eraseSpray(at point: CGPoint) { eraseSpray(from: point, to: point) }
        private func eraseSpray(from a: CGPoint, to b: CGPoint) {
            let r = parent.eraserRadius
            let before = workingSplats
            workingSplats = SprayRenderer.erase(workingSplats, alongFrom: a, to: b, radius: r)
            if workingSplats.count != before.count || workingSplats != before {
                sprayLayer?.splats = workingSplats
                sprayLayer?.setNeedsDisplay(dirtyRect(a, b, pad: r + 6))
            }
        }

        /// Bounding rect in container coords for the segment a→b (content space) padded out.
        private func dirtyRect(_ a: CGPoint, _ b: CGPoint, pad: CGFloat) -> CGRect {
            guard let canvas else { return .zero }
            let z = canvas.zoomScale, off = canvas.contentOffset
            func toView(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * z - off.x, y: p.y * z - off.y) }
            let va = toView(a), vb = toView(b)
            let p = pad * z
            return CGRect(x: min(va.x, vb.x) - p, y: min(va.y, vb.y) - p,
                          width: abs(va.x - vb.x) + 2 * p, height: abs(va.y - vb.y) + 2 * p)
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

/// Draws the ACTIVE spray/erase stroke in real time (content space, tracking zoom/pan).
/// Settled spray lives in a separate transform-tracked image view, so this only ever
/// renders the in-progress stroke (live spray) or the working copy while erasing.
final class SprayLayerView: UIView {
    var splats: [SpraySplat] = [] { didSet { setNeedsDisplay() } }   // working copy (erase)
    var liveSplat: SpraySplat?                                       // in-progress spray
    private var zoom: CGFloat = 1
    private var offset: CGPoint = .zero

    func update(zoom: CGFloat, offset: CGPoint) {
        self.zoom = zoom
        self.offset = offset
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let z = zoom, off = offset
        let map: (Float, Float) -> CGPoint = { x, y in
            CGPoint(x: CGFloat(x) * z - off.x, y: CGFloat(y) * z - off.y)
        }
        SprayRenderer.draw(splats, in: ctx, scale: z, clip: rect, map: map)
        if let liveSplat { SprayRenderer.draw([liveSplat], in: ctx, scale: z, clip: rect, map: map) }
    }

    /// Renders splats into a content-space image (capped resolution) for the settled layer.
    /// Returns the image and its content-space bounding box, or (nil, .null) when empty.
    static func renderImage(_ splats: [SpraySplat]) -> (UIImage?, CGRect) {
        var bbox = CGRect.null
        for s in splats { if let b = s.bounds { bbox = bbox.union(b) } }
        guard !bbox.isNull, bbox.width > 0, bbox.height > 0 else { return (nil, .null) }
        bbox = bbox.insetBy(dx: -4, dy: -4)
        let scale = min(2.0, 2048 / max(bbox.width, bbox.height))   // crisp, but bounded
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let size = CGSize(width: bbox.width * scale, height: bbox.height * scale)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { c in
            SprayRenderer.draw(splats, in: c.cgContext, scale: scale, clip: nil,
                               map: { x, y in CGPoint(x: (CGFloat(x) - bbox.minX) * scale,
                                                      y: (CGFloat(y) - bbox.minY) * scale) })
        }
        return (image, bbox)
    }
}

/// Shared 米字格 geometry so the live canvas and the gallery thumbnail use the same
/// cell size (and therefore line up).
enum MiziGrid {
    static let cellSize: CGFloat = 230   // content-space points per character cell
}

/// Draws an "infinite" 米字格 (rice-grid) practice grid, aligned to canvas content space
/// so the cells stay put under the writing as the child zooms/pans. Solid red cell
/// borders with dashed centre cross + diagonals, the traditional handwriting guide.
final class MiziGridView: UIView {
    private var zoom: CGFloat = 1
    private var offset: CGPoint = .zero
    private let baseCell = MiziGrid.cellSize

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
