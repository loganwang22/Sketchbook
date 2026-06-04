import PencilKit
import UIKit

enum BrushKind: String, CaseIterable, Identifiable {
    case pen, crayon, fountainPen, paintbrush, spray, eraser

    var id: String { rawValue }

    /// Label shown in the HUD when the pencil gesture switches tools.
    var displayName: String {
        switch self {
        case .fountainPen: return "Fountain pen"
        case .paintbrush:  return "Watercolor"
        case .spray:       return "Spray"
        default:           return rawValue.capitalized
        }
    }

    /// Dock icon. All icons are flat monochrome for a consistent style: SF Symbols where
    /// one exists, otherwise a hand-drawn monochrome shape (no SF Symbol for crayon /
    /// quill / spray can).
    enum Glyph { case symbol(String), custom(CustomBrushIcon.Kind) }
    var glyph: Glyph {
        switch self {
        case .pen:         return .symbol("pencil.tip")
        case .crayon:      return .custom(.crayon)
        case .fountainPen: return .custom(.quill)
        case .paintbrush:  return .symbol("paintbrush.fill")    // flat loaded oil brush
        case .spray:       return .custom(.sprayCan)
        case .eraser:      return .symbol("eraser.fill")
        }
    }
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

    /// The watercolor brush lays down a broader, loaded-brush stroke than the ink tools.
    var paintWidth: Double {
        switch self {
        case .small:  return 14
        case .medium: return 34
        case .big:    return 64
        }
    }

    /// Spray "nozzle" size — the guide-stroke width that drives how wide paint scatters.
    var sprayWidth: Double {
        switch self {
        case .small:  return 6
        case .medium: return 10
        case .big:    return 16
        }
    }

    /// Stroke width for a given brush. Eraser and watercolor lay down broader strokes.
    func width(for brush: BrushKind) -> Double {
        switch brush {
        case .eraser:     return eraserWidth
        case .paintbrush: return paintWidth
        case .spray:      return sprayWidth
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
        case .paintbrush:  return PKInkingTool(.watercolor,  color: color, width: size.width(for: self))
        // Spray draws a thin pen guide line; the canvas scatters it into paint speckles
        // on lift (custom spray — PencilKit has no airbrush ink). See sprayLastStroke.
        case .spray:       return PKInkingTool(.pen,         color: color, width: size.width(for: self))
        case .eraser:      return PKEraserTool(.bitmap, width: size.width(for: self))
        }
    }
}
