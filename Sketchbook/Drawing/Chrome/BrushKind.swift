import PencilKit
import UIKit

enum BrushKind: String, CaseIterable, Identifiable {
    // Order matters: the rail lists them in this order, grouped by `group`.
    case pen, monoline, fountainPen, crayon, paintbrush   // "pen strokes" (PencilKit inks)
    case airbrush, oil                                    // "artist brushes" (app-rendered)
    case eraser

    var id: String { rawValue }

    /// The two soft groups in the left rail. Eraser stands on its own.
    enum Group { case pen, brush }
    var group: Group? {
        switch self {
        case .airbrush, .oil: return .brush
        case .eraser:         return nil
        default:              return .pen
        }
    }

    /// App-rendered paint brushes (not PencilKit ink). Captured by the spray recognizer.
    var isCustom: Bool { group == .brush }
    var sprayStyle: SpraySplat.Style? {
        switch self {
        case .airbrush: return .airbrush
        case .oil:      return .oil
        default:        return nil
        }
    }

    /// Label shown in the HUD when the pencil gesture switches tools.
    var displayName: String {
        switch self {
        case .fountainPen: return "Fountain pen"
        case .paintbrush:  return "Watercolor"
        case .airbrush:    return "Airbrush"
        case .oil:         return "Oil paint"
        default:           return rawValue.capitalized
        }
    }

    /// Dock icon — all flat monochrome shapes for a consistent style.
    enum Glyph { case symbol(String), custom(CustomBrushIcon.Kind) }
    var glyph: Glyph {
        switch self {
        case .pen:         return .custom(.pen)
        case .monoline:    return .custom(.monoline)
        case .fountainPen: return .custom(.quill)
        case .crayon:      return .custom(.crayon)
        case .paintbrush:  return .symbol("paintbrush.fill")   // watercolor
        case .airbrush:    return .custom(.airbrush)
        case .oil:         return .custom(.oilTube)
        case .eraser:      return .symbol("eraser.fill")
        }
    }

    /// Stroke width range (content points) the size control interpolates across.
    var widthRange: ClosedRange<Double> {
        switch self {
        case .eraser:     return 12...170
        case .paintbrush: return 5...95
        case .airbrush:   return 5...85
        case .oil:        return 7...120
        default:          return 1...42   // pen-like inks: thinner min, wider max
        }
    }

    /// `fraction` is the 0...1 size position.
    func width(fraction: Double) -> Double {
        let r = widthRange
        return r.lowerBound + (r.upperBound - r.lowerBound) * min(max(fraction, 0), 1)
    }

    func pkTool(color: UIColor, fraction: Double) -> PKTool {
        let w = width(fraction: fraction)
        switch self {
        case .pen:         return PKInkingTool(.pen,         color: color, width: w)
        case .monoline:    return PKInkingTool(.monoline,    color: color, width: w)
        case .fountainPen: return PKInkingTool(.fountainPen, color: color, width: w)
        case .crayon:      return PKInkingTool(.crayon,      color: color, width: w)
        case .paintbrush:  return PKInkingTool(.watercolor,  color: color, width: w)
        // Custom brushes don't draw via PencilKit; the .pen tool just carries the width.
        case .airbrush, .oil: return PKInkingTool(.pen, color: color, width: w)
        case .eraser:      return PKEraserTool(.bitmap, width: w)
        }
    }
}
