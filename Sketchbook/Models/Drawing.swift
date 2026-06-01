import Foundation

struct Drawing: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var pkDrawingData: Data
    var backgroundColor: ColorRGBA
    var photoLayer: PhotoLayer?
    var thumbnailFilename: String
    /// Per-painting palette. Optional so drawings saved before palettes existed still
    /// decode (nil -> fall back to the default KidPalette).
    var palette: [ColorRGBA]?

    static func empty() -> Drawing {
        let now = Date()
        return Drawing(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            pkDrawingData: Data(),
            backgroundColor: KidPalette.defaultBackground,
            photoLayer: nil,
            thumbnailFilename: "thumb.png",
            palette: KidPalette.colors.map(\.color)
        )
    }

    mutating func touch() {
        updatedAt = Date()
    }
}
