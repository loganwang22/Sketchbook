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

    // Picture-edit gesture state (captured at gesture start).
    @State private var editGestureActive = false
    @State private var editBaseScale: Double = 1
    @State private var editBaseRotation: Double = 0
    @State private var editBaseOffset: CGSize = .zero

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
    /// Move/scale/rotate only applies to photos placed on the canvas.
    private var canEditPhoto: Bool {
        viewModel.photoLayer != nil && photoMode != .reference
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

            if viewModel.editingPhoto {
                photoEditOverlay
            }

            if let hud = viewModel.hudMessage {
                statusHUD(hud)
            }

            if viewModel.straightLineActive {
                Label("Straight line", systemImage: "ruler")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.primary.opacity(0.1)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 150)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.hudMessage)
        .animation(.easeInOut(duration: 0.2), value: viewModel.straightLineActive)
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
                         photoScale: viewModel.photoLayer?.scale ?? 1,
                         photoRotation: viewModel.photoLayer?.rotation ?? 0,
                         photoOffset: CGSize(width: viewModel.photoLayer?.offsetX ?? 0,
                                             height: viewModel.photoLayer?.offsetY ?? 0),
                         onStrokeEnd: { viewModel.scheduleSave() },
                         onCanvasReady: { viewModel.canvasRef = $0 },
                         onPencilDoubleTap: { viewModel.togglePencilEraser() },
                         onStraightLineActiveChanged: { viewModel.straightLineActive = $0 })
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
                canEditPhoto: canEditPhoto,
                photoHidden: viewModel.photoHidden,
                onTogglePhoto: { viewModel.photoHidden.toggle() },
                onEditPhoto: {
                    viewModel.photoHidden = false
                    viewModel.editingPhoto = true
                },
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

    // MARK: picture edit mode

    private var photoEditOverlay: some View {
        ZStack {
            // Transparent surface that captures the transform gestures (so the pencil
            // can't draw while adjusting the picture).
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(photoEditGesture)

            VStack {
                HStack(spacing: 16) {
                    Label("Move • pinch • twist the picture", systemImage: "hand.draw")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        viewModel.editingPhoto = false
                        try? viewModel.flushSave()
                    }
                    .font(.headline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(.regularMaterial)
                Spacer()
            }
        }
    }

    private var photoEditGesture: some Gesture {
        let drag = DragGesture()
        let magnify = MagnifyGesture()
        let rotate = RotateGesture()
        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
            .onChanged { value in
                if !editGestureActive {
                    editGestureActive = true
                    editBaseScale = viewModel.photoLayer?.scale ?? 1
                    editBaseRotation = viewModel.photoLayer?.rotation ?? 0
                    editBaseOffset = CGSize(width: viewModel.photoLayer?.offsetX ?? 0,
                                            height: viewModel.photoLayer?.offsetY ?? 0)
                }
                let zoom = viewModel.canvasRef?.zoomScale ?? 1
                let magnification = value.first?.second?.magnification ?? 1
                let rotationDelta = value.second?.rotation.radians ?? 0
                let translation = value.first?.first?.translation ?? .zero
                viewModel.updatePhotoTransform(
                    scale: editBaseScale * Double(magnification),
                    rotation: editBaseRotation + rotationDelta,
                    offset: CGSize(width: editBaseOffset.width + translation.width / zoom,
                                   height: editBaseOffset.height + translation.height / zoom)
                )
            }
            .onEnded { _ in
                editGestureActive = false
                try? viewModel.flushSave()
            }
    }

    private func statusHUD(_ message: String) -> some View {
        Text(message)
            .font(.title3.weight(.bold))
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.primary.opacity(0.1)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 92)
            .transition(.opacity)
            .allowsHitTesting(false)
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
