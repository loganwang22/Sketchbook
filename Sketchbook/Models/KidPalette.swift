import Foundation

enum KidPalette {
    struct Entry: Equatable {
        let name: String
        let color: ColorRGBA
    }

    /// 10 muted, less-saturated colours sized for a 4–10-year-old's eye.
    /// HSV saturation roughly 0.3–0.55, value roughly 0.45–0.95.
    static let colors: [Entry] = [
        Entry(name: "Dusty red",   color: ColorRGBA(r: 0.78, g: 0.48, b: 0.48)),
        Entry(name: "Warm coral",  color: ColorRGBA(r: 0.88, g: 0.63, b: 0.50)),
        Entry(name: "Mustard",     color: ColorRGBA(r: 0.83, g: 0.69, b: 0.38)),
        Entry(name: "Sage green",  color: ColorRGBA(r: 0.61, g: 0.71, b: 0.56)),
        Entry(name: "Dusty teal",  color: ColorRGBA(r: 0.48, g: 0.65, b: 0.66)),
        Entry(name: "Soft slate",  color: ColorRGBA(r: 0.49, g: 0.56, b: 0.67)),
        Entry(name: "Lavender",    color: ColorRGBA(r: 0.66, g: 0.60, b: 0.72)),
        Entry(name: "Blush pink",  color: ColorRGBA(r: 0.89, g: 0.72, b: 0.75)),
        Entry(name: "Cream",       color: ColorRGBA(r: 0.95, g: 0.90, b: 0.82)),
        Entry(name: "Charcoal",    color: ColorRGBA(r: 0.24, g: 0.24, b: 0.27)),
    ]

    static let defaultBackground = ColorRGBA(r: 0.949, g: 0.902, b: 0.816)
}
