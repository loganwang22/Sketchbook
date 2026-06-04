import PencilKit
import UIKit

enum BrushKind: String, CaseIterable, Identifiable {
    case pen, crayon, fountainPen, paintbrush, spray, eraser

    var id: String { rawValue }

    /// Label shown in the HUD when the pencil gesture switches tools.
    var displayName: String {
        switch self {
        case .fountainPen: return "Fountain pen"
        case .paintbrush:  return "Oil paint"
        case .spray:       return "Spray"
        default:           return rawValue.capitalized
        }
    }

    /// Dock icon. Most brushes use an SF Symbol; the quill has no symbol so it uses the
    /// feather emoji (a quill pen literally is a feather).
    enum Glyph { case symbol(String), text(String) }
    var glyph: Glyph {
        switch self {
        case .pen:         return .symbol("pencil.tip")
        case .crayon:      return .symbol("scribble.variable")  // waxy scribble, not a pencil
        case .fountainPen: return .text("🪶")                   // pen with a feather (quill)
        case .paintbrush:  return .symbol("paintbrush.fill")    // flat loaded oil brush
        case .spray:       return .symbol("sparkles")           // scattered spray burst
        case .eraser:      return .symbol("eraser.fill")
        }
    }

    /// True for brushes whose stroke is post-processed after it's drawn (spray scatter).
    var isSpray: Bool { self == .spray }
}

enum BrushSize: Double, CaseIterable, Identifiable {
    case small = 4
    case medium = 10
    case big = 22
    var id: Double { rawValue }

    /// Erasers are far larger than ink brushes so kids can clear space quickly;
    /// the biggest clears roughly half a 米字格 cell in one pass.
    var eraserWidth: Double {
        switch self {
        case .small:  return 28
        case .medium: return 70
        case .big:    return 130
        }
    }

    /// The oil brush lays down a much thicker, loaded-brush stroke than the ink tools.
    var paintWidth: Double {
        switch self {
        case .small:  return 14
        case .medium: return 34
        case .big:    return 64
        }
    }

    /// Stroke width for a given brush (eraser and oil brush use their own larger scales).
    func width(for brush: BrushKind) -> Double {
        switch brush {
        case .eraser:     return eraserWidth
        case .paintbrush: return paintWidth
        default:          return rawValue
        }
    }
}

extension BrushKind {
    func pkTool(color: UIColor, size: BrushSize) -> PKTool {
        switch self {
        case .pen:         return PKInkingTool(.pen,         color: color, width: size.width(for: self))
        case .crayon:      return PKInkingTool(.crayon,      color: color, width: size.width(for: self))
        case .fountainPen: return PKInkingTool(.fountainPen, color: color, width: size.width(for: self))
        case .paintbrush:  return PKInkingTool(.reed,        color: color, width: size.width(for: self))
        // Spray draws as a normal pen line, then the canvas scatters it into dots on lift.
        case .spray:       return PKInkingTool(.pen,         color: color, width: size.width(for: self))
        case .eraser:      return PKEraserTool(.bitmap, width: size.width(for: self))
        }
    }
}
