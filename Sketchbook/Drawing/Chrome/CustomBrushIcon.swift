import SwiftUI

/// Monochrome icons for brushes that have no SF Symbol (crayon, quill, spray can).
/// Drawn filled in the foreground colour so they match the flat, single-colour style
/// of the SF Symbols used by the other brushes.
struct CustomBrushIcon: View {
    enum Kind { case pen, monoline, crayon, quill, sprayCan, airbrush, oilTube }
    let kind: Kind

    var body: some View {
        // Even-odd fill so the crayon's bands and the quill/pen cut-outs punch through.
        shape.fill(.primary, style: FillStyle(eoFill: true))
             .aspectRatio(1, contentMode: .fit)
    }

    private var shape: AnyShape {
        switch kind {
        case .pen:      return AnyShape(PenNibShape())
        case .monoline: return AnyShape(MonolineShape())
        case .crayon:   return AnyShape(CrayonShape())
        case .quill:    return AnyShape(QuillShape())
        case .sprayCan: return AnyShape(SprayCanShape())
        case .airbrush: return AnyShape(AirbrushShape())
        case .oilTube:  return AnyShape(OilTubeShape())
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

/// A pen nib: a triangle pointing down with a vent hole and slit punched out.
private struct PenNibShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(36, 18))
        path.addLine(to: p(64, 18))
        path.addLine(to: p(56, 72))
        path.addLine(to: p(50, 92))   // tip
        path.addLine(to: p(44, 72))
        path.closeSubpath()
        path.addEllipse(in: box(rect, 45, 34, 10, 10))   // vent hole
        path.addRect(box(rect, 48.5, 48, 3, 30))         // slit
        return path
    }
}

/// A monoline pen: a thick, uniform, rounded diagonal bar.
private struct MonolineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = scaler(rect)
        let s = min(rect.width, rect.height) / 100
        var line = Path()
        line.move(to: p(26, 76))
        line.addLine(to: p(74, 24))
        return line.strokedPath(.init(lineWidth: s * 20, lineCap: .round))
    }
}

/// An airbrush: a nozzle on the left throwing a soft cone of mist to the right.
private struct AirbrushShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.addRoundedRect(in: box(rect, 12, 42, 18, 14), cornerSize: cs(rect, 3))  // nozzle
        path.move(to: p(30, 45))                                                     // cone
        path.addLine(to: p(80, 26))
        path.addLine(to: p(80, 72))
        path.addLine(to: p(30, 53))
        path.closeSubpath()
        path.addEllipse(in: box(rect, 84, 32, 6, 6))                                 // mist
        path.addEllipse(in: box(rect, 89, 47, 5, 5))
        path.addEllipse(in: box(rect, 84, 60, 6, 6))
        return path
    }
    private func cs(_ rect: CGRect, _ r: CGFloat) -> CGSize {
        let s = min(rect.width, rect.height) / 100
        return CGSize(width: r * s, height: r * s)
    }
}

/// An oil-paint tube: crimped top, body, cap, and a blob squeezing out the bottom.
private struct OilTubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(38, 10))                          // crimped top
        path.addLine(to: p(62, 10))
        path.addLine(to: p(58, 24))
        path.addLine(to: p(42, 24))
        path.closeSubpath()
        path.addRoundedRect(in: box(rect, 40, 24, 20, 50), cornerSize: cs(rect, 5))  // body
        path.addRect(box(rect, 45, 74, 10, 8))                                       // cap
        path.addEllipse(in: box(rect, 43, 82, 14, 14))                               // blob
        return path
    }
    private func cs(_ rect: CGRect, _ r: CGFloat) -> CGSize {
        let s = min(rect.width, rect.height) / 100
        return CGSize(width: r * s, height: r * s)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach([CustomBrushIcon.Kind.pen, .monoline, .crayon, .quill, .sprayCan, .airbrush, .oilTube], id: \.self) {
            CustomBrushIcon(kind: $0)
        }
    }
    .frame(height: 40)
    .padding()
}

extension CustomBrushIcon.Kind: Hashable {}
