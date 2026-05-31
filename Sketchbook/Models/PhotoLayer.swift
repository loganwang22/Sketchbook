import Foundation
import CoreGraphics

struct PhotoLayer: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable {
        case reference
        case trace
        case coloringPage
    }

    var imageFilename: String
    var mode: Mode
    var opacity: Double
    var transform: CGAffineTransform

    init(imageFilename: String, mode: Mode, opacity: Double = 1.0, transform: CGAffineTransform = .identity) {
        self.imageFilename = imageFilename
        self.mode = mode
        self.opacity = opacity
        self.transform = transform
    }

    private enum CodingKeys: String, CodingKey {
        case imageFilename, mode, opacity
        case transformMatrix
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imageFilename = try c.decode(String.self, forKey: .imageFilename)
        mode = try c.decode(Mode.self, forKey: .mode)
        opacity = try c.decode(Double.self, forKey: .opacity)
        let m = try c.decode([CGFloat].self, forKey: .transformMatrix)
        guard m.count == 6 else {
            throw DecodingError.dataCorruptedError(forKey: .transformMatrix, in: c,
                debugDescription: "Expected 6 floats, got \(m.count)")
        }
        transform = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(imageFilename, forKey: .imageFilename)
        try c.encode(mode, forKey: .mode)
        try c.encode(opacity, forKey: .opacity)
        try c.encode([transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty],
                     forKey: .transformMatrix)
    }
}
