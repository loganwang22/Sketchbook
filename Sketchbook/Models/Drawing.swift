import Foundation

struct Drawing: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var pkDrawingData: Data
    var backgroundColor: ColorRGBA
    var photoLayer: PhotoLayer?
    var thumbnailFilename: String

    static func empty() -> Drawing {
        let now = Date()
        return Drawing(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            pkDrawingData: Data(),
            backgroundColor: KidPalette.defaultBackground,
            photoLayer: nil,
            thumbnailFilename: "thumb.png"
        )
    }

    mutating func touch() {
        updatedAt = Date()
    }
}
