import SwiftUI
import PencilKit

struct DrawingView: View {
    @StateObject var viewModel: DrawingViewModel
    @EnvironmentObject var fingerPref: FingerDrawingPreference
    @Environment(\.dismiss) private var dismiss

    @State private var showParentGate: PendingGatedAction?
    @State private var showBackgroundPopover = false
    @State private var showShareSheet = false
    @State private var showPhotoFlow = false

    enum PendingGatedAction: Identifiable {
        case share, clear, enableFingerDrawing, openCamera, openPhotos
        var id: String {
            switch self {
            case .share: return "share"
            case .clear: return "clear"
            case .enableFingerDrawing: return "ffd"
            case .openCamera: return "cam"
            case .openPhotos: return "lib"
            }
        }
    }

    var body: some View {
        ZStack {
            viewModel.backgroundColor.swiftUIColor
                .ignoresSafeArea()

            if let layer = viewModel.photoLayer,
               let image = loadPhoto(for: layer) {
                PhotoLayerView(image: image,
                               opacity: layer.opacity,
                               transform: layer.transform)
                    .ignoresSafeArea()
            }

            PencilCanvas(drawingData: $viewModel.pkDrawingData,
                         tool: viewModel.currentTool,
                         allowFingerDrawing: fingerPref.allowFingerDrawing,
                         onStrokeEnd: { viewModel.scheduleSave() })

            VStack {
                TopBar(
                    onBack: { try? viewModel.flushSave(); dismiss() },
                    onUndo: { /* wired in a later task via UndoManager */ },
                    onRedo: { },
                    canUndo: true, canRedo: true,
                    onShare: { showParentGate = .share },
                    onClear: { showParentGate = .clear },
                    onBackgroundColor: { showBackgroundPopover = true },
                    onToggleFingerDrawing: {
                        if fingerPref.allowFingerDrawing {
                            fingerPref.allowFingerDrawing = false
                        } else {
                            showParentGate = .enableFingerDrawing
                        }
                    },
                    fingerDrawingOn: fingerPref.allowFingerDrawing
                )
                Spacer()
                ToolDock(brush: $viewModel.selectedBrush,
                         size: $viewModel.selectedSize,
                         color: $viewModel.selectedColor,
                         onPhotoTap: { showPhotoFlow = true })
                .padding(.bottom, 12)
            }
        }
        .sheet(item: $showParentGate) { action in
            ParentGateSheet(
                onPass: { handleGated(action); showParentGate = nil },
                onCancel: { showParentGate = nil }
            )
        }
        .sheet(isPresented: $showBackgroundPopover) {
            BackgroundColorPopover(selectedColor: $viewModel.backgroundColor,
                                   onClose: { showBackgroundPopover = false })
        }
        .sheet(isPresented: $showPhotoFlow) {
            PhotoFlow(
                drawingId: viewModel.drawing.id,
                photoLayer: $viewModel.photoLayer,
                onClose: { showPhotoFlow = false }
            )
        }
        .onDisappear { try? viewModel.flushSave() }
    }

    private func handleGated(_ action: PendingGatedAction) {
        switch action {
        case .share:
            showShareSheet = true   // wired in Task 34
        case .clear:
            try? viewModel.clearCanvas()
        case .enableFingerDrawing:
            fingerPref.allowFingerDrawing = true
        case .openCamera, .openPhotos:
            showPhotoFlow = true    // photo flow re-presents in Task 33
        }
    }

    private func loadPhoto(for layer: PhotoLayer) -> UIImage? {
        DrawingRepository().loadPhoto(for: viewModel.drawing.id, filename: layer.imageFilename)
    }
}
