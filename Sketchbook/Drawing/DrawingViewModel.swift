import Foundation
import SwiftUI
import Combine
import UIKit
import PencilKit

@MainActor
final class DrawingViewModel: ObservableObject {
    @Published var pkDrawingData: Data
    @Published var backgroundColor: ColorRGBA
    @Published var photoLayer: PhotoLayer?
    @Published var selectedBrush: BrushKind = .pen
    @Published var selectedSize: BrushSize = .medium
    @Published var selectedColor: ColorRGBA = KidPalette.colors[9].color // charcoal

    private(set) var drawing: Drawing
    weak var canvasRef: PKCanvasView?
    var canUndo: Bool { canvasRef?.undoManager?.canUndo ?? false }
    var canRedo: Bool { canvasRef?.undoManager?.canRedo ?? false }
    func undo() { canvasRef?.undoManager?.undo() }
    func redo() { canvasRef?.undoManager?.redo() }
    private let store: DrawingStore
    private var saveTask: Task<Void, Never>?
    private let debounce: TimeInterval

    init(drawing: Drawing, store: DrawingStore, debounce: TimeInterval = 1.0) {
        self.drawing = drawing
        self.store = store
        self.debounce = debounce
        self.pkDrawingData = drawing.pkDrawingData
        self.backgroundColor = drawing.backgroundColor
        self.photoLayer = drawing.photoLayer
    }

    var currentTool: PKTool {
        selectedBrush.pkTool(color: selectedColor.uiColor, size: selectedSize)
    }

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
        drawing.pkDrawingData = pkDrawingData
        drawing.backgroundColor = backgroundColor
        drawing.photoLayer = photoLayer
        drawing.touch()
        try store.save(drawing)
    }

    func clearCanvas() throws {
        pkDrawingData = Data()
        try flushSave()
    }
}
