import Foundation
import UIKit

/// Pure filesystem CRUD for drawings. No SwiftUI imports.
final class DrawingRepository {
    private let rootDirectory: URL
    private let fileManager: FileManager

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    /// Convenience initialiser that targets `Documents/Drawings/`.
    convenience init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.init(rootDirectory: docs.appendingPathComponent("Drawings", isDirectory: true))
    }

    func directory(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    // MARK: drawing JSON

    func save(_ drawing: Drawing) throws {
        let dir = directory(for: drawing.id)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(drawing)
        try data.write(to: dir.appendingPathComponent("drawing.json"), options: .atomic)
    }

    func load(id: UUID) throws -> Drawing {
        let url = directory(for: id).appendingPathComponent("drawing.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Drawing.self, from: data)
    }

    func listAll() throws -> [Drawing] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return [] }
        let entries = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        var drawings: [Drawing] = []
        for dir in entries where dir.hasDirectoryPath {
            let jsonURL = dir.appendingPathComponent("drawing.json")
            guard let data = try? Data(contentsOf: jsonURL),
                  let drawing = try? JSONDecoder().decode(Drawing.self, from: data) else {
                continue
            }
            drawings.append(drawing)
        }
        return drawings.sorted { $0.updatedAt > $1.updatedAt }
    }

    func delete(id: UUID) throws {
        let dir = directory(for: id)
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
    }

    // MARK: image assets

    @discardableResult
    func savePhoto(_ image: UIImage, for id: UUID, filename: String = "photo.png") throws -> String {
        let dir = directory(for: id)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = image.pngData() else {
            throw NSError(domain: "DrawingRepository", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not PNG-encode image"])
        }
        try data.write(to: dir.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    func loadPhoto(for id: UUID, filename: String = "photo.png") -> UIImage? {
        let url = directory(for: id).appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    func saveThumbnail(_ image: UIImage, for id: UUID) throws -> String {
        try savePhoto(image, for: id, filename: "thumb.png")
    }

    func loadThumbnail(for id: UUID) -> UIImage? {
        loadPhoto(for: id, filename: "thumb.png")
    }
}
