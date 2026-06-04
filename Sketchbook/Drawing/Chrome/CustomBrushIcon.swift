import SwiftUI

/// Monochrome icons for brushes that have no SF Symbol (crayon, quill, spray can).
/// Drawn filled in the foreground colour so they match the flat, single-colour style
/// of the SF Symbols used by the other brushes.
struct CustomBrushIcon: View {
    enum Kind { case crayon, quill, sprayCan }
    let kind: Kind

    var body: some View {
        // Even-odd fill so the crayon's bands and the quill's shaft punch through.
        shape.fill(.primary, style: FillStyle(eoFill: true))
             .aspectRatio(1, contentMode: .fit)
    }

    private var shape: AnyShape {
        switch kind {
        case .crayon:   return AnyShape(CrayonShape())
        case .quill:    return AnyShape(QuillShape())
        case .sprayCan: return AnyShape(SprayCanShape())
        }
    }
}

/// All shapes are authored in a 100×100 box and scaled to fit.
private func scaler(_ rect: CGRect) -> (CGFloat, CGFloat) -> CGPoint {
    let s = min(rect.width, rect.height) / 100
    let dx = rect.minX + (rect.width - 100 * s) / 2
    let dy = rect.minY + (rect.height - 100 * s) / 2
    return { x, y in CGPoint(x: dx + x * s, y: dy + y * s) }
}
private func box(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    let s = min(rect.width, rect.height) / 100
    let dx = rect.minX + (rect.width - 100 * s) / 2
    let dy = rect.minY + (rect.height - 100 * s) / 2
    return CGRect(x: dx + x * s, y: dy + y * s, width: w * s, height: h * s)
}

/// A chunky crayon: short blunt cone, fat rounded body — clearly not a thin pencil.
private struct CrayonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(50, 8))
        path.addLine(to: p(66, 34))            // cone right
        path.addLine(to: p(66, 84))
        path.addQuadCurve(to: p(56, 94), control: p(66, 94))   // rounded bottom-right
        path.addLine(to: p(44, 94))
        path.addQuadCurve(to: p(34, 84), control: p(34, 94))   // rounded bottom-left
        path.addLine(to: p(34, 34))            // cone left
        path.closeSubpath()
        // Wrapper bands (punched out so they read as label stripes).
        path.addRect(box(rect, 34, 44, 32, 5))
        path.addRect(box(rect, 34, 54, 32, 5))
        return path
    }
}

/// A feather quill: a tilted vane tapering to a nib, with a hollow shaft line.
private struct QuillShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(82, 14))                                   // top tip
        path.addQuadCurve(to: p(30, 70), control: p(40, 24))       // outer edge
        path.addLine(to: p(18, 90))                                // down to nib
        path.addLine(to: p(30, 82))                                // nib notch
        path.addQuadCurve(to: p(72, 36), control: p(48, 70))       // inner edge
        path.closeSubpath()
        // Shaft line (punched out) running down the middle of the vane.
        var shaft = Path()
        shaft.move(to: p(74, 24))
        shaft.addLine(to: p(24, 86))
        path.addPath(shaft.strokedPath(.init(lineWidth: min(rect.width, rect.height) / 100 * 3,
                                             lineCap: .round)))
        return path
    }
}

/// A spray can: body, cap, nozzle, and a little burst of mist.
private struct SprayCanShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: box(rect, 34, 42, 32, 50), cornerSize: cs(rect, 8))   // body
        path.addRoundedRect(in: box(rect, 40, 28, 20, 14), cornerSize: cs(rect, 3))   // cap
        path.addRect(box(rect, 46, 21, 8, 7))                                          // nozzle
        path.addEllipse(in: box(rect, 60, 13, 7, 7))                                   // mist
        path.addEllipse(in: box(rect, 71, 8, 6, 6))
        path.addEllipse(in: box(rect, 69, 22, 5, 5))
        return path
    }
    private func cs(_ rect: CGRect, _ r: CGFloat) -> CGSize {
        let s = min(rect.width, rect.height) / 100
        return CGSize(width: r * s, height: r * s)
    }
}

#Preview {
    HStack(spacing: 20) {
        CustomBrushIcon(kind: .crayon)
        CustomBrushIcon(kind: .quill)
        CustomBrushIcon(kind: .sprayCan)
    }
    .frame(height: 40)
    .padding()
}
