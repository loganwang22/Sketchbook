import SwiftUI
import PencilKit

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    let tool: PKTool
    let allowFingerDrawing: Bool
    let onStrokeEnd: () -> Void
    let onCanvasReady: (PKCanvasView) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.tool = tool
        canvas.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.minimumZoomScale = 0.25
        canvas.maximumZoomScale = 4.0
        canvas.contentSize = CGSize(width: 6000, height: 6000)
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = true
        if !drawingData.isEmpty, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        onCanvasReady(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.tool = tool
        canvas.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        if drawingData.isEmpty && !canvas.drawing.strokes.isEmpty {
            canvas.drawing = PKDrawing()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilCanvas
        init(_ parent: PencilCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
            parent.onStrokeEnd()
        }
    }
}
