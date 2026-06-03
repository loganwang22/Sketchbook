import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var pendingDeleteId: UUID?
    @Published var shareItem: ShareItem?
    let store: DrawingStore

    /// Wraps the rendered image so `.sheet(item:)` can present the share sheet.
    struct ShareItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    init(store: DrawingStore) { self.store = store }

    /// Returns a fresh in-memory drawing. It is NOT written to disk or added to the
    /// gallery until the first real edit saves it — so opening a new page and leaving
    /// without drawing anything doesn't leave behind an empty painting.
    func createNew(kind: DrawingKind = .freeform) -> Drawing {
        Drawing.empty(kind: kind)
    }

    // MARK: delete (parent-gated)

    func requestDelete(id: UUID) { pendingDeleteId = id }

    func cancelDelete() { pendingDeleteId = nil }

    func confirmDelete() throws {
        guard let id = pendingDeleteId else { return }
        try store.delete(id: id)
        pendingDeleteId = nil
    }

    // MARK: share

    /// Renders the drawing at print resolution and stages it for the share sheet.
    func share(_ drawing: Drawing) {
        let repo = DrawingRepository()
        var images: [String: UIImage] = [:]
        for layer in drawing.photoLayers {
            images[layer.imageFilename] = repo.loadPhoto(for: drawing.id, filename: layer.imageFilename)
        }
        guard let image = ThumbnailRenderer.render(
            drawing: drawing,
            photoImages: images,
            canvasSize: CGSize(width: 2048, height: 1536)
        ) else { return }
        shareItem = ShareItem(image: image)
    }
}
