import Foundation

struct Drawing: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var pkDrawingData: Data
    var backgroundColor: ColorRGBA
    var photoLayers: [PhotoLayer]
    var thumbnailFilename: String
    /// Per-painting palette. Optional so drawings saved before palettes existed still
    /// decode (nil -> fall back to the default KidPalette).
    var palette: [ColorRGBA]?

    init(id: UUID, createdAt: Date, updatedAt: Date, pkDrawingData: Data,
         backgroundColor: ColorRGBA, photoLayers: [PhotoLayer] = [],
         thumbnailFilename: String, palette: [ColorRGBA]? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pkDrawingData = pkDrawingData
        self.backgroundColor = backgroundColor
        self.photoLayers = photoLayers
        self.thumbnailFilename = thumbnailFilename
        self.palette = palette
    }

    static func empty() -> Drawing {
        let now = Date()
        return Drawing(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            pkDrawingData: Data(),
            backgroundColor: KidPalette.defaultBackground,
            photoLayers: [],
            thumbnailFilename: "thumb.png",
            palette: KidPalette.colors.map(\.color)
        )
    }

    mutating func touch() {
        updatedAt = Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, pkDrawingData, backgroundColor
        case photoLayers, photoLayer   // photoLayer is the legacy single-photo key
        case thumbnailFilename, palette
    }

    // Custom decode to migrate older saves that stored a single `photoLayer` into the
    // new `photoLayers` array.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        pkDrawingData = try c.decode(Data.self, forKey: .pkDrawingData)
        backgroundColor = try c.decode(ColorRGBA.self, forKey: .backgroundColor)
        thumbnailFilename = try c.decode(String.self, forKey: .thumbnailFilename)
        palette = try c.decodeIfPresent([ColorRGBA].self, forKey: .palette)
        if let layers = try c.decodeIfPresent([PhotoLayer].self, forKey: .photoLayers) {
            photoLayers = layers
        } else if let legacy = try c.decodeIfPresent(PhotoLayer.self, forKey: .photoLayer) {
            photoLayers = [legacy]
        } else {
            photoLayers = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(pkDrawingData, forKey: .pkDrawingData)
        try c.encode(backgroundColor, forKey: .backgroundColor)
        try c.encode(photoLayers, forKey: .photoLayers)
        try c.encode(thumbnailFilename, forKey: .thumbnailFilename)
        try c.encodeIfPresent(palette, forKey: .palette)
    }
}
