import PencilKit
import UIKit

enum BrushKind: String, CaseIterable, Identifiable {
    case pen, crayon, fountainPen, paintbrush, eraser

    var id: String { rawValue }
    /// Label shown in the HUD when the pencil gesture switches tools.
    var displayName: String {
        switch self {
        case .fountainPen: return "Fountain pen"
        default:           return rawValue.capitalized
        }
    }
    var displaySymbol: String {
        switch self {
        case .pen:         return "pencil.tip"
        case .crayon:      return "pencil"
        case .fountainPen: return "signature"   // fancy calligraphic flourish
        case .paintbrush:  return "paintbrush.pointed.fill"
        case .eraser:      return "eraser.fill"
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

    /// The paintbrush lays down a much thicker, loaded-brush stroke than the ink tools.
    var paintWidth: Double {
        switch self {
        case .small:  return 14
        case .medium: return 34
        case .big:    return 64
        }
    }

    /// Stroke width for a given brush (eraser and paintbrush use their own larger scales).
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
        case .paintbrush:  return PKInkingTool(.watercolor,  color: color, width: size.width(for: self))
        case .eraser:      return PKEraserTool(.bitmap, width: size.width(for: self))
        }
    }
}
