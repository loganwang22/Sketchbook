import Foundation

struct PhotoLayer: Codable, Equatable, Identifiable {
    enum Mode: String, Codable, CaseIterable {
        case reference
        case trace
        case coloringPage
    }

    var id: UUID
    var imageFilename: String
    var mode: Mode
    var opacity: Double
    // User adjustments from the "Edit picture" mode, in canvas content space so they
    // track zoom/pan. Defaults place the photo filling the viewport where it was added.
    var scale: Double
    var rotation: Double   // radians
    var offsetX: Double    // content-space points
    var offsetY: Double

    init(id: UUID = UUID(), imageFilename: String, mode: Mode, opacity: Double = 1.0,
         scale: Double = 1, rotation: Double = 0, offsetX: Double = 0, offsetY: Double = 0) {
        self.id = id
        self.imageFilename = imageFilename
        self.mode = mode
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    private enum CodingKeys: String, CodingKey {
        case id, imageFilename, mode, opacity, scale, rotation, offsetX, offsetY
    }

    // Custom decode so drawings saved before these fields existed still load (missing
    // keys fall back to identity placement). encode(to:) is synthesised from CodingKeys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        imageFilename = try c.decode(String.self, forKey: .imageFilename)
        mode = try c.decode(Mode.self, forKey: .mode)
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        offsetX = try c.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0
        offsetY = try c.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
    }
}
