import Foundation
import Combine

@MainActor
final class DrawingStore: ObservableObject {
    @Published private(set) var drawings: [Drawing] = []
    private let repository: DrawingRepository

    init(repository: DrawingRepository = DrawingRepository()) {
        self.repository = repository
        self.drawings = (try? repository.listAll()) ?? []
    }

    @discardableResult
    func createNew() throws -> Drawing {
        let d = Drawing.empty()
        try repository.save(d)
        drawings.insert(d, at: 0)
        return d
    }

    func save(_ drawing: Drawing) throws {
        try repository.save(drawing)
        if let idx = drawings.firstIndex(where: { $0.id == drawing.id }) {
            drawings.remove(at: idx)
        }
        drawings.insert(drawing, at: 0)
    }

    func delete(id: UUID) throws {
        try repository.delete(id: id)
        drawings.removeAll { $0.id == id }
    }
}
