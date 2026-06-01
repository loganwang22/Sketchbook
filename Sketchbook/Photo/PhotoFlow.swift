import SwiftUI

struct PhotoFlow: View {
    let drawingId: UUID
    @Binding var photoLayer: PhotoLayer?
    let onClose: () -> Void

    @State private var stage: Stage = .source
    @State private var pickedImage: UIImage?

    enum Stage {
        case source
        case picker(PhotoSourceSheet.Source)
        case mode
    }

    var body: some View {
        Group {
            switch stage {
            case .source:
                PhotoSourceSheet(
                    onPick: { source in stage = .picker(source) },
                    onCancel: onClose
                )
            case .picker(.camera):
                CameraPicker(onCapture: handlePicked, onCancel: onClose)
            case .picker(.library):
                PhotoLibraryPicker(onPick: handlePicked, onCancel: onClose)
            case .picker(.starter):
                StarterPhotoGrid(onPick: handlePicked, onCancel: onClose)
            case .mode:
                if let image = pickedImage {
                    PhotoModeSheet(preview: image, onPick: handleMode, onCancel: onClose)
                }
            }
        }
    }

    private func handlePicked(_ image: UIImage) {
        pickedImage = image
        stage = .mode
    }

    private func handleMode(_ mode: PhotoLayer.Mode) {
        guard let image = pickedImage else { return }
        // Trace and colour overlay the canvas, so they use a transparent contour to
        // preserve the paper colour. Reference shows the real photo in the side panel.
        let processed: UIImage
        switch mode {
        case .trace, .coloringPage:
            processed = ColoringPageFilter.lineArt(from: image) ?? image
        case .reference:
            processed = image
        }
        let repo = DrawingRepository()
        // Unique filename so swapping the photo changes the layer's identity, which
        // re-triggers the canvas's image reload (a fixed "photo.png" would not).
        let filename = "photo-\(UUID().uuidString).png"
        guard (try? repo.savePhoto(processed, for: drawingId, filename: filename)) != nil else {
            onClose(); return
        }
        photoLayer = PhotoLayer(imageFilename: filename, mode: mode,
                                opacity: mode == .trace ? 0.5 : 1.0)
        onClose()
    }
}
