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
    @State private var photoImages: [String: UIImage] = [:]

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

    private var canvasPhotoLayers: [PhotoLayer] {
        viewModel.photoLayers.filter { $0.mode != .reference }
    }
    private var referenceImages: [(id: UUID, image: UIImage)] {
        viewModel.photoLayers.compactMap { layer in
            guard layer.mode == .reference, let img = photoImages[layer.imageFilename] else { return nil }
            return (layer.id, img)
        }
    }
    private var showingReferencePanel: Bool {
        !referenceImages.isEmpty && !viewModel.photosHidden
    }
    private var artboardPhotos: [ArtboardPhoto] {
        canvasPhotoLayers.compactMap { layer in
            guard let img = photoImages[layer.imageFilename] else { return nil }
            return ArtboardPhoto(id: layer.id, image: img, mode: layer.mode,
                                 opacity: layer.opacity, scale: layer.scale,
                                 rotation: layer.rotation,
                                 offset: CGSize(width: layer.offsetX, height: layer.offsetY),
                                 hidden: viewModel.photosHidden)
        }
    }
    private var photoFilenamesKey: String {
        viewModel.photoLayers.map(\.imageFilename).joined(separator: ",")
    }

    var body: some View {
        ZStack {
            if showingReferencePanel {
                HStack(spacing: 0) {
                    artboard
                    Divider()
                    ReferencePanel(images: referenceImages)
                        .frame(width: 360)
                }
            } else {
                artboard
            }

            chrome

            if viewModel.editingPhoto {
                photoEditOverlay
            }

            if let hud = viewModel.hudMessage {
                statusHUD(hud)
            }

            if viewModel.straightLineActive {
                straightLineIndicator
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.hudMessage)
        .animation(.easeInOut(duration: 0.2), value: viewModel.straightLineActive)
        .task(id: photoFilenamesKey) {
            loadPhotoImages()
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
                onAdd: { viewModel.addPhotoLayer($0) },
                onClose: { showPhotoFlow = false }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
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
                         photos: artboardPhotos,
                         showGrid: viewModel.isChineseWriting,
                         initialZoom: viewModel.isChineseWriting ? 0.65 : nil,
                         onStrokeEnd: { viewModel.scheduleSave() },
                         onCanvasReady: { viewModel.canvasRef = $0 },
                         onPencilDoubleTap: { viewModel.togglePencilEraser() },
                         onStraightLineActiveChanged: { viewModel.straightLineActive = $0 })
                // In writing mode, inset the page so the grid clears the top bar and
                // bottom dock and has a comfortable margin from the screen edges.
                .padding(.top, viewModel.isChineseWriting ? gridInset.top : 0)
                .padding(.bottom, viewModel.isChineseWriting ? gridInset.bottom : 0)
                .padding(.horizontal, viewModel.isChineseWriting ? gridInset.side : 0)
        }
    }

    private var gridInset: (top: CGFloat, bottom: CGFloat, side: CGFloat) {
        (top: 88, bottom: 92, side: 40)
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
                hasPhoto: !viewModel.photoLayers.isEmpty,
                canEditPhoto: viewModel.hasCanvasPhoto,
                photoHidden: viewModel.photosHidden,
                onTogglePhoto: { viewModel.photosHidden.toggle() },
                onEditPhoto: { viewModel.beginEditingPhotos() },
                onRemovePhoto: { viewModel.removeAllPhotos() }
            )
            Spacer()
            ToolDock(brush: $viewModel.selectedBrush,
                     size: $viewModel.selectedSize,
                     color: $viewModel.selectedColor,
                     palette: $viewModel.palette,
                     onPhotoTap: { showPhotoFlow = true },
                     colorsOnly: viewModel.isChineseWriting)
            .padding(.bottom, 12)
        }
    }

    // MARK: picture edit mode

    private var photoEditOverlay: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(photoEditGesture)

            VStack {
                HStack(spacing: 16) {
                    if canvasPhotoLayers.count > 1 {
                        layerStrip
                    } else {
                        Label("Move • pinch • twist", systemImage: "hand.draw")
                            .font(.headline)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        viewModel.removeActivePhoto()
                        if !viewModel.hasCanvasPhoto { viewModel.editingPhoto = false }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .disabled(viewModel.activePhotoID == nil)
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

    /// Thumbnails of the canvas pictures; tap one to choose which to move/scale/rotate.
    private var layerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(canvasPhotoLayers) { layer in
                    let isActive = (layer.id == viewModel.activePhotoID)
                    Group {
                        if let img = photoImages[layer.imageFilename] {
                            Image(uiImage: img).resizable().scaledToFit()
                        } else {
                            Color(.systemGray5)
                        }
                    }
                    .frame(width: 56, height: 42)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? Color.accentColor : .secondary.opacity(0.3),
                                lineWidth: isActive ? 3 : 1))
                    .onTapGesture { viewModel.activePhotoID = layer.id }
                }
            }
        }
        .frame(maxWidth: 360)
    }

    private var photoEditGesture: some Gesture {
        let drag = DragGesture()
        let magnify = MagnifyGesture()
        let rotate = RotateGesture()
        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
            .onChanged { value in
                if !editGestureActive {
                    editGestureActive = true
                    editBaseScale = viewModel.activePhotoLayer?.scale ?? 1
                    editBaseRotation = viewModel.activePhotoLayer?.rotation ?? 0
                    editBaseOffset = CGSize(width: viewModel.activePhotoLayer?.offsetX ?? 0,
                                            height: viewModel.activePhotoLayer?.offsetY ?? 0)
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

    private var straightLineIndicator: some View {
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

    private func handleGated(_ action: PendingGatedAction) {
        switch action {
        case .share:
            shareImage = ThumbnailRenderer.render(
                drawing: viewModel.drawing,
                photoImages: photoImages,
                canvasSize: CGSize(width: 2048, height: 1536)
            )
            showShareSheet = true
        case .clear:
            try? viewModel.clearCanvas()
        }
    }

    private func loadPhotoImages() {
        let repo = DrawingRepository()
        var images: [String: UIImage] = [:]
        for layer in viewModel.photoLayers {
            images[layer.imageFilename] = repo.loadPhoto(for: viewModel.drawing.id,
                                                         filename: layer.imageFilename)
        }
        photoImages = images
    }
}

/// Side panel shown in "Look at it" mode — the reference(s) the child draws from.
private struct ReferencePanel: View {
    let images: [(id: UUID, image: UIImage)]
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(images, id: \.id) { item in
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .padding(20)
            }
        }
    }
}
