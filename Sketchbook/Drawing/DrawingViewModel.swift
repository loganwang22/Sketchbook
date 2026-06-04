import Foundation
import SwiftUI
import Combine
import UIKit
import PencilKit

@MainActor
final class DrawingViewModel: ObservableObject {
    @Published var pkDrawingData: Data { didSet { markDirty() } }
    @Published var backgroundColor: ColorRGBA { didSet { markDirty() } }
    @Published var photoLayers: [PhotoLayer] { didSet { markDirty() } }
    @Published var spraySplats: [SpraySplat] { didSet { markDirty(); sprayRevision &+= 1 } }
    @Published var palette: [ColorRGBA] { didSet { markDirty() } }
    /// Bumped on every spray change so the canvas knows to resync (load / undo / clear).
    private(set) var sprayRevision = 0
    @Published var photosHidden = false  // transient view toggle, not part of the artwork
    @Published var editingPhoto = false  // transient: picture move/scale/rotate mode
    @Published var activePhotoID: UUID?  // transient: which picture edit/remove targets
    @Published var hudMessage: String?   // transient on-screen status (e.g. tool toggle)
    @Published var straightLineActive = false  // Shift held: strokes snap to H/V lines
    @Published var selectedBrush: BrushKind = .pen
    @Published var selectedSize: BrushSize = .medium
    @Published var selectedColor: ColorRGBA

    private(set) var drawing: Drawing
    weak var canvasRef: PKCanvasView?
    var canUndo: Bool { canvasRef?.undoManager?.canUndo ?? false }
    var canRedo: Bool { canvasRef?.undoManager?.canRedo ?? false }
    func undo() { canvasRef?.undoManager?.undo() }
    func redo() { canvasRef?.undoManager?.redo() }

    private let store: DrawingStore
    private var saveTask: Task<Void, Never>?
    private let debounce: TimeInterval
    /// Brush to restore when the pencil barrel gesture toggles back from the eraser.
    private var lastNonEraserBrush: BrushKind = .pen
    private var hudTask: Task<Void, Never>?
    /// True only after a real edit. Gating saves on this keeps "open to view" from
    /// bumping a painting's position (ordering is by last edit, not last opened).
    private var isDirty = false

    init(drawing: Drawing, store: DrawingStore, debounce: TimeInterval = 1.0) {
        self.drawing = drawing
        self.store = store
        self.debounce = debounce
        self.pkDrawingData = drawing.pkDrawingData
        self.backgroundColor = drawing.backgroundColor
        self.photoLayers = drawing.photoLayers
        self.spraySplats = drawing.spraySplats
        let loadedPalette = drawing.palette ?? KidPalette.colors.map(\.color)
        self.palette = loadedPalette
        self.selectedColor = loadedPalette.last ?? KidPalette.colors[9].color
    }

    /// Chinese writing pages show the 米字格 grid and lock the tool to the pen.
    var isChineseWriting: Bool { drawing.kind == .chineseWriting }

    var currentTool: PKTool {
        selectedBrush.pkTool(color: selectedColor.uiColor, size: selectedSize)
    }

    private func markDirty() { isDirty = true }

    /// Called by the canvas after each stroke ends; coalesces saves on a debounce.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.debounce ?? 1.0) * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            try? self.flushSave()
        }
    }

    func flushSave() throws {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty else { return }   // nothing changed — don't reorder or rewrite
        drawing.pkDrawingData = pkDrawingData
        drawing.backgroundColor = backgroundColor
        drawing.photoLayers = photoLayers
        drawing.spraySplats = spraySplats
        drawing.palette = palette
        drawing.touch()
        try store.save(drawing)
        isDirty = false
        regenerateThumbnail()
    }

    /// Renders the current drawing (background + photos + strokes) to a thumbnail PNG
    /// so the gallery can show a real preview. Cheap at 400×300; runs on every save.
    private func regenerateThumbnail() {
        let repo = DrawingRepository()
        var images: [String: UIImage] = [:]
        for layer in drawing.photoLayers {
            images[layer.imageFilename] = repo.loadPhoto(for: drawing.id, filename: layer.imageFilename)
        }
        guard let thumb = ThumbnailRenderer.render(drawing: drawing, photoImages: images) else { return }
        try? repo.saveThumbnail(thumb, for: drawing.id)
    }

    func clearCanvas() throws {
        pkDrawingData = Data()
        spraySplats = []
        try flushSave()
    }

    /// Commits a spray add/erase as a single, reversible step. Registered on the canvas's
    /// UndoManager so spray interleaves with stroke undo/redo and the toolbar buttons work.
    func commitSpraySplats(_ new: [SpraySplat]) {
        let old = spraySplats
        guard old != new else { return }
        spraySplats = new
        canvasRef?.undoManager?.registerUndo(withTarget: self) { vm in
            vm.commitSpraySplats(old)   // re-registers the redo automatically
        }
        scheduleSave()
    }

    // MARK: photos

    /// True when at least one picture sits on the canvas (trace/colour), i.e. editable.
    var hasCanvasPhoto: Bool { photoLayers.contains { $0.mode != .reference } }

    func addPhotoLayer(_ layer: PhotoLayer) {
        photoLayers.append(layer)
        activePhotoID = layer.id
        photosHidden = false
        try? flushSave()
    }

    func removeActivePhoto() {
        guard let id = activePhotoID else { return }
        photoLayers.removeAll { $0.id == id }
        activePhotoID = photoLayers.last { $0.mode != .reference }?.id
        try? flushSave()
    }

    func removeAllPhotos() {
        photoLayers = []
        activePhotoID = nil
        photosHidden = false
        try? flushSave()
    }

    /// Ensures a canvas photo is selected, then enters move/scale/rotate mode.
    func beginEditingPhotos() {
        if activePhotoID == nil || !photoLayers.contains(where: { $0.id == activePhotoID && $0.mode != .reference }) {
            activePhotoID = photoLayers.last { $0.mode != .reference }?.id
        }
        guard activePhotoID != nil else { return }
        photosHidden = false
        editingPhoto = true
    }

    /// Apple Pencil barrel gesture (double-tap / squeeze): flip to the eraser, or back
    /// to the last brush used. Works in both drawing and Chinese-writing mode.
    func togglePencilEraser() {
        if selectedBrush == .eraser {
            selectedBrush = lastNonEraserBrush
        } else {
            lastNonEraserBrush = selectedBrush
            selectedBrush = .eraser
        }
        showHUD(selectedBrush == .eraser ? "Eraser" : selectedBrush.displayName)
    }

    /// Briefly shows a status message (auto-clears) so toggles are obvious.
    func showHUD(_ message: String) {
        hudMessage = message
        hudTask?.cancel()
        hudTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard let self, !Task.isCancelled else { return }
            self.hudMessage = nil
        }
    }

    /// The picture currently targeted by edit gestures / remove.
    var activePhotoLayer: PhotoLayer? {
        guard let id = activePhotoID else { return nil }
        return photoLayers.first { $0.id == id }
    }

    /// Live update from the picture-edit gestures (values in canvas content space).
    func updatePhotoTransform(scale: Double, rotation: Double, offset: CGSize) {
        guard let id = activePhotoID,
              let index = photoLayers.firstIndex(where: { $0.id == id }) else { return }
        photoLayers[index].scale = min(max(scale, 0.2), 6)
        photoLayers[index].rotation = rotation
        photoLayers[index].offsetX = Double(offset.width)
        photoLayers[index].offsetY = Double(offset.height)
    }
}
