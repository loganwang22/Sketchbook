import SwiftUI
import UIKit

struct ColorRGBA: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = min(max(r, 0), 1)
        self.g = min(max(g, 0), 1)
        self.b = min(max(b, 0), 1)
        self.a = min(max(a, 0), 1)
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var uiColor: UIColor {
        UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

extension ColorRGBA {
    /// Build from HSL (each component 0...1; hue wraps around).
    init(h: Double, s: Double, l: Double, a: Double = 1.0) {
        let hue = h - floor(h)
        let sat = min(max(s, 0), 1)
        let light = min(max(l, 0), 1)
        guard sat > 0 else { self.init(r: light, g: light, b: light, a: a); return }
        let q = light < 0.5 ? light * (1 + sat) : light + sat - light * sat
        let p = 2 * light - q
        func channel(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        self.init(r: channel(hue + 1.0 / 3), g: channel(hue), b: channel(hue - 1.0 / 3), a: a)
    }

    /// (hue, saturation, lightness), each 0...1. Hue is 0 for greys.
    var hsl: (h: Double, s: Double, l: Double) {
        let mx = max(r, g, b), mn = min(r, g, b)
        let light = (mx + mn) / 2
        guard mx != mn else { return (0, 0, light) }
        let d = mx - mn
        let sat = light > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var hue: Double
        if mx == r { hue = (g - b) / d + (g < b ? 6 : 0) }
        else if mx == g { hue = (b - r) / d + 2 }
        else { hue = (r - g) / d + 4 }
        return (hue / 6, sat, light)
    }
}
