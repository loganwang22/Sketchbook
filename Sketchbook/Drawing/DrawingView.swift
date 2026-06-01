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
    @State private var shareImage: UIImage?
    @State private var activePhotoImage: UIImage?

    enum PendingGatedAction: Identifiable {
        case share, clear
        var id: String {
            switch self {
            case .share: return "share"
            case .clear: return "clear"
            }
        }
    }

    private var photoMode: PhotoLayer.Mode? { viewModel.photoLayer?.mode }

    /// Reference mode shows the photo in a side panel (unless hidden); every other
    /// mode places the photo on the canvas itself.
    private var showingReferencePanel: Bool {
        photoMode == .reference && activePhotoImage != nil && !viewModel.photoHidden
    }
    private var artboardPhoto: UIImage? {
        photoMode == .reference ? nil : activePhotoImage
    }

    var body: some View {
        ZStack {
            // Drawing area — split only when a reference panel is showing.
            if showingReferencePanel, let image = activePhotoImage {
                HStack(spacing: 0) {
                    artboard
                    Divider()
                    ReferencePanel(image: image)
                        .frame(width: 360)
                }
            } else {
                artboard
            }

            // Chrome sits on top at full width, so the back button and dock keep
            // their normal positions regardless of the split.
            chrome
        }
        .task(id: viewModel.photoLayer?.imageFilename) {
            activePhotoImage = loadActivePhoto()
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
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .onChange(of: viewModel.photoLayer?.imageFilename) { _, _ in
            viewModel.photoHidden = false
        }
        .onDisappear { try? viewModel.flushSave() }
    }

    private var artboard: some View {
        ZStack {
            viewModel.backgroundColor.swiftUIColor
                .ignoresSafeArea()

            PencilCanvas(drawingData: $viewModel.pkDrawingData,
                         tool: viewModel.currentTool,
                         allowFingerDrawing: fingerPref.allowFingerDrawing,
                         photoImage: artboardPhoto,
                         photoHidden: viewModel.photoHidden,
                         photoMode: photoMode,
                         photoOpacity: viewModel.photoLayer?.opacity ?? 1.0,
                         onStrokeEnd: { viewModel.scheduleSave() },
                         onCanvasReady: { viewModel.canvasRef = $0 },
                         onPencilDoubleTap: { viewModel.togglePencilEraser() })
        }
    }

    private var chrome: some View {
        VStack {
            TopBar(
                onBack: { try? viewModel.flushSave(); dismiss() },
                onUndo: { viewModel.undo() },
                onRedo: { viewModel.redo() },
                canUndo: viewModel.canUndo, canRedo: viewModel.canRedo,
                onShare: { showParentGate = .share },
                onClear: { showParentGate = .clear },
                onBackgroundColor: { showBackgroundPopover = true },
                onToggleFingerDrawing: { fingerPref.allowFingerDrawing.toggle() },
                fingerDrawingOn: fingerPref.allowFingerDrawing,
                hasPhoto: viewModel.photoLayer != nil,
                photoHidden: viewModel.photoHidden,
                onTogglePhoto: { viewModel.photoHidden.toggle() },
                onRemovePhoto: { viewModel.removePhoto() }
            )
            Spacer()
            ToolDock(brush: $viewModel.selectedBrush,
                     size: $viewModel.selectedSize,
                     color: $viewModel.selectedColor,
                     palette: $viewModel.palette,
                     onPhotoTap: { showPhotoFlow = true })
            .padding(.bottom, 12)
        }
    }

    private func handleGated(_ action: PendingGatedAction) {
        switch action {
        case .share:
            shareImage = ThumbnailRenderer.render(
                drawing: viewModel.drawing,
                photoImage: activePhotoImage,
                canvasSize: CGSize(width: 2048, height: 1536)
            )
            showShareSheet = true
        case .clear:
            try? viewModel.clearCanvas()
        }
    }

    private func loadActivePhoto() -> UIImage? {
        guard let layer = viewModel.photoLayer else { return nil }
        return DrawingRepository().loadPhoto(for: viewModel.drawing.id, filename: layer.imageFilename)
    }
}

/// Side panel shown in "Look at it" mode — the reference the child draws from.
private struct ReferencePanel: View {
    let image: UIImage
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(20)
        }
    }
}
