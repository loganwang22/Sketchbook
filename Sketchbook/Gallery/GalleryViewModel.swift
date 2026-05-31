import Foundation
import Combine
import SwiftUI

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var isWiggling = false
    @Published var pendingDeleteId: UUID?
    let store: DrawingStore

    init(store: DrawingStore) { self.store = store }

    @discardableResult
    func createNew() throws -> Drawing {
        try store.createNew()
    }

    func toggleWiggle() { isWiggling.toggle() }

    func requestDelete(id: UUID) { pendingDeleteId = id }

    func cancelDelete() { pendingDeleteId = nil }

    func confirmDelete() throws {
        guard let id = pendingDeleteId else { return }
        try store.delete(id: id)
        pendingDeleteId = nil
    }
}
