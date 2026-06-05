import SwiftUI

/// Always-visible stroke-size control: a wedge bar (thin → thick) with a draggable
/// handle whose inner dot previews the current size. `fraction` is 0...1.
struct StrokeWidthBar: View {
    @Binding var fraction: Double
    var tint: Color = .primary

    private let handle: CGFloat = 34
    private let height: CGFloat = 34

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let f = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Wedge()
                    .fill(.primary.opacity(0.16))
                    .frame(height: 18)
                    .frame(maxHeight: .infinity, alignment: .center)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(.primary.opacity(0.2)))
                    .overlay(Circle().fill(tint).frame(width: 6 + CGFloat(f) * 18,
                                                        height: 6 + CGFloat(f) * 18))
                    .frame(width: handle, height: handle)
                    .shadow(radius: 1.5)
                    .offset(x: f * (w - handle))
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                fraction = min(max((v.location.x - handle / 2) / (w - handle), 0), 1)
            })
        }
        .frame(width: 160, height: height)
        .accessibilityLabel("Stroke size")
    }
}

/// A left-thin, right-thick bar — a visual hint that dragging right grows the stroke.
private struct Wedge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        p.move(to: CGPoint(x: rect.minX, y: midY - 1))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: midY + 1))
        p.closeSubpath()
        return p
    }
}

#Preview {
    @Previewable @State var f = 0.4
    return StrokeWidthBar(fraction: $f).padding()
}
