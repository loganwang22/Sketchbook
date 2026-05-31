import PencilKit
import UIKit

enum BrushKind: String, CaseIterable, Identifiable {
    case pen, crayon, marker, paintbrush, eraser

    var id: String { rawValue }
    var displaySymbol: String {
        switch self {
        case .pen:        return "pencil.tip"
        case .crayon:     return "pencil"
        case .marker:     return "highlighter"
        case .paintbrush: return "paintbrush.pointed.fill"
        case .eraser:     return "eraser.fill"
        }
    }
}

enum BrushSize: Double, CaseIterable, Identifiable {
    case small = 4
    case medium = 10
    case big = 22
    var id: Double { rawValue }
}

extension BrushKind {
    func pkTool(color: UIColor, size: BrushSize) -> PKTool {
        switch self {
        case .pen:        return PKInkingTool(.pen,        color: color, width: size.rawValue)
        case .crayon:     return PKInkingTool(.crayon,     color: color, width: size.rawValue)
        case .marker:     return PKInkingTool(.marker,     color: color, width: size.rawValue)
        case .paintbrush: return PKInkingTool(.watercolor, color: color, width: size.rawValue)
        case .eraser:     return PKEraserTool(.bitmap, width: size.rawValue)
        }
    }
}
