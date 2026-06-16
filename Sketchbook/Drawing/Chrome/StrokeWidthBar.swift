import SwiftUI

/// Kid-friendly stroke-size picker: a row of dots that grow left→right. Tap the size you
/// want; the chosen one fills with the current colour and gets a ring. `fraction` is 0...1.
struct StrokeWidthBar: View {
    @Binding var fraction: Double
    var tint: Color = .primary

    private let presets: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(presets.indices, id: \.self) { i in
                dot(i)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedIndex)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stroke size")
    }

    private var selectedIndex: Int {
        presets.indices.min(by: { abs(presets[$0] - fraction) < abs(presets[$1] - fraction) }) ?? 0
    }

    private func dot(_ i: Int) -> some View {
        let isSelected = (i == selectedIndex)
        let diameter = 8 + CGFloat(presets[i]) * 24      // 8...32
        return Button {
            fraction = presets[i]
        } label: {
            Circle()
                .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.primary.opacity(0.35)))
                .frame(width: diameter, height: diameter)
                .frame(width: 46, height: 46)
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                            in: Circle())
                .overlay(Circle().stroke(.tint, lineWidth: isSelected ? 2.5 : 0).frame(width: 44, height: 44))
                // Whole 46×46 cell is tappable — otherwise only the tiny dot is, so small
                // sizes needed a second, more precise tap.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Size \(i + 1)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    @Previewable @State var f = 0.5
    return StrokeWidthBar(fraction: $f, tint: .blue).padding()
}
