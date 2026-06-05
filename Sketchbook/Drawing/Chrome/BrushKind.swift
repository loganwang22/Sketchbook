import PencilKit
import UIKit

enum BrushKind: String, CaseIterable, Identifiable {
    // Order matters: the rail lists them in this order, grouped by `group`.
    case pen, pencil, marker, monoline, fountainPen, crayon, paintbrush  // "pen strokes"
    case spray                                                            // "artist brushes"
    case eraser

    var id: String { rawValue }

    /// The two soft groups in the left rail. Eraser stands on its own.
    enum Group { case pen, brush }
    var group: Group? {
        switch self {
        case .spray:  return .brush
        case .eraser: return nil
        default:      return .pen
        }
    }

    /// Label shown in the HUD when the pencil gesture switches tools.
    var displayName: String {
        switch self {
        case .fountainPen: return "Fountain pen"
        case .paintbrush:  return "Watercolor"
        default:           return rawValue.capitalized
        }
    }

    /// Dock icon. Flat monochrome for a consistent style: SF Symbols where one exists,
    /// otherwise a hand-drawn shape (no SF Symbol for crayon / quill / spray can).
    enum Glyph { case symbol(String), custom(CustomBrushIcon.Kind) }
    var glyph: Glyph {
        switch self {
        case .pen:         return .symbol("pencil.tip")
        case .pencil:      return .symbol("pencil")
        case .marker:      return .symbol("highlighter")
        case .monoline:    return .symbol("line.diagonal")
        case .fountainPen: return .custom(.quill)
        case .crayon:      return .custom(.crayon)
        case .paintbrush:  return .symbol("paintbrush.fill")    // watercolor
        case .spray:       return .custom(.sprayCan)
        case .eraser:      return .symbol("eraser.fill")
        }
    }

    /// Stroke width range (content points) the size slider interpolates across. Eraser,
    /// watercolor and spray have their own scales.
    var widthRange: ClosedRange<Double> {
        switch self {
        case .eraser:     return 16...140
        case .paintbrush: return 8...70
        case .spray:      return 4...24
        default:          return 2...28
        }
    }

    /// `fraction` is the 0...1 size-slider position.
    func width(fraction: Double) -> Double {
        let r = widthRange
        return r.lowerBound + (r.upperBound - r.lowerBound) * min(max(fraction, 0), 1)
    }

    func pkTool(color: UIColor, fraction: Double) -> PKTool {
        let w = width(fraction: fraction)
        switch self {
        case .pen:         return PKInkingTool(.pen,         color: color, width: w)
        case .pencil:      return PKInkingTool(.pencil,      color: color, width: w)
        case .marker:      return PKInkingTool(.marker,      color: color, width: w)
        case .monoline:    return PKInkingTool(.monoline,    color: color, width: w)
        case .fountainPen: return PKInkingTool(.fountainPen, color: color, width: w)
        case .crayon:      return PKInkingTool(.crayon,      color: color, width: w)
        case .paintbrush:  return PKInkingTool(.watercolor,  color: color, width: w)
        // Spray draws a thin pen guide that the canvas converts to custom particles.
        case .spray:       return PKInkingTool(.pen,         color: color, width: w)
        case .eraser:      return PKEraserTool(.bitmap, width: w)
        }
    }
}
