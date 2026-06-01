import Foundation
import SwiftUI
import Combine
import UIKit
import PencilKit

@MainActor
final class DrawingViewModel: ObservableObject {
    @Published var pkDrawingData: Data { didSet { markDirty() } }
    @Published var backgroundColor: ColorRGBA { didSet { markDirty() } }
    @Published var photoLayer: PhotoLayer? { didSet { markDirty() } }
    @Published var palette: [ColorRGBA] { didSet { markDirty() } }
    @Published var photoHidden = false   // transient view toggle, not part of the artwork
    @Published var editingPhoto = false  // transient: picture move/scale/rotate mode
    @Published var hudMessage: String?   // transient on-screen status (e.g. tool toggle)
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
    /// Brush to restore when the pencil double-tap toggles back from the eraser.
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
        self.photoLayer = drawing.photoLayer
        let loadedPalette = drawing.palette ?? KidPalette.colors.map(\.color)
        self.palette = loadedPalette
        self.selectedColor = loadedPalette.last ?? KidPalette.colors[9].color
    }

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
        drawing.photoLayer = photoLayer
        drawing.palette = palette
        drawing.touch()
        try store.save(drawing)
        isDirty = false
        regenerateThumbnail()
    }

    /// Renders the current drawing (background + photo + strokes) to a thumbnail PNG
    /// so the gallery can show a real preview. Cheap at 400×300; runs on every save.
    private func regenerateThumbnail() {
        let repo = DrawingRepository()
        let photo = drawing.photoLayer.flatMap {
            repo.loadPhoto(for: drawing.id, filename: $0.imageFilename)
        }
        guard let thumb = ThumbnailRenderer.render(drawing: drawing, photoImage: photo) else { return }
        try? repo.saveThumbnail(thumb, for: drawing.id)
    }

    func clearCanvas() throws {
        pkDrawingData = Data()
        try flushSave()
    }

    func removePhoto() {
        photoLayer = nil
        photoHidden = false
        try? flushSave()
    }

    /// Apple Pencil double-tap: flip to the eraser, or back to the last brush used.
    func togglePencilEraser() {
        if selectedBrush == .eraser {
            selectedBrush = lastNonEraserBrush
        } else {
            lastNonEraserBrush = selectedBrush
            selectedBrush = .eraser
        }
        showHUD(selectedBrush == .eraser ? "Eraser" : selectedBrush.rawValue.capitalized)
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

    /// Live update from the picture-edit gestures (values in canvas content space).
    func updatePhotoTransform(scale: Double, rotation: Double, offset: CGSize) {
        guard var layer = photoLayer else { return }
        layer.scale = min(max(scale, 0.2), 6)
        layer.rotation = rotation
        layer.offsetX = Double(offset.width)
        layer.offsetY = Double(offset.height)
        photoLayer = layer
    }
}
