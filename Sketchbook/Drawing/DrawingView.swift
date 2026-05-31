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

    var body: some View {
        Group {
            if photoMode == .reference, let image = activePhotoImage {
                // "Look at it" — reference pinned beside the canvas, never overlapping.
                HStack(spacing: 0) {
                    canvasZone
                    Divider()
                    ReferencePanel(image: image)
                        .frame(width: 360)
                }
            } else {
                canvasZone
            }
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
            try? viewModel.flushSave()
        }
        .onDisappear { try? viewModel.flushSave() }
    }

    /// The drawing surface + chrome. The photo sits *below* the canvas for trace
    /// mode, or *on top* (multiply-blended, non-interactive) for colour mode.
    private var canvasZone: some View {
        ZStack {
            viewModel.backgroundColor.swiftUIColor
                .ignoresSafeArea()

            if photoMode == .trace, let image = activePhotoImage {
                PhotoLayerView(image: image, opacity: viewModel.photoLayer?.opacity ?? 0.35)
                    .ignoresSafeArea()
            }

            PencilCanvas(drawingData: $viewModel.pkDrawingData,
                         tool: viewModel.currentTool,
                         allowFingerDrawing: fingerPref.allowFingerDrawing,
                         onStrokeEnd: { viewModel.scheduleSave() },
                         onCanvasReady: { viewModel.canvasRef = $0 })

            if photoMode == .coloringPage, let image = activePhotoImage {
                PhotoLayerView(image: image, opacity: 1.0, multiplyBlend: true)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

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
                    fingerDrawingOn: fingerPref.allowFingerDrawing
                )
                if viewModel.photoLayer != nil {
                    RemovePhotoButton { viewModel.removePhoto() }
                }
                Spacer()
                ToolDock(brush: $viewModel.selectedBrush,
                         size: $viewModel.selectedSize,
                         color: $viewModel.selectedColor,
                         onPhotoTap: { showPhotoFlow = true })
                .padding(.bottom, 12)
            }
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
            VStack(spacing: 12) {
                Text("Draw this!")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .padding(20)
        }
    }
}

/// Small pill shown while a photo is active, letting the child clear it.
private struct RemovePhotoButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Remove picture", systemImage: "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}
