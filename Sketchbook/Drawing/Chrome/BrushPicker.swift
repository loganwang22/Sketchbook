import SwiftUI

struct BrushPicker: View {
    @Binding var selectedBrush: BrushKind
    @Binding var selectedSize: BrushSize
    /// Which brushes to offer. Chinese writing mode passes `[.pen, .eraser]`.
    var brushes: [BrushKind] = BrushKind.allCases
    @State private var bloomedBrush: BrushKind?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(brushes) { brush in
                brushButton(brush)
            }
        }
        .overlay(alignment: .top) {
            if let b = bloomedBrush, b == selectedBrush {
                sizeBloom
                    .offset(y: -72)
                    .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bloomedBrush)
    }

    private func brushButton(_ brush: BrushKind) -> some View {
        let isSelected = (brush == selectedBrush)
        return Button {
            if isSelected {
                bloomedBrush = (bloomedBrush == brush) ? nil : brush
            } else {
                selectedBrush = brush
                bloomedBrush = nil
            }
        } label: {
            glyph(brush)
                .frame(width: 56, height: 56)
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear),
                            in: Circle())
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .offset(y: isSelected ? -6 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(brush.displayName)
    }

    @ViewBuilder
    private func glyph(_ brush: BrushKind) -> some View {
        switch brush.glyph {
        case .symbol(let name):
            Image(systemName: name).font(.system(size: 28, weight: .semibold))
        case .custom(let kind):
            CustomBrushIcon(kind: kind).frame(width: 30, height: 30)
        }
    }

    private var sizeBloom: some View {
        HStack(spacing: 16) {
            ForEach(BrushSize.allCases) { size in
                Button { selectedSize = size; bloomedBrush = nil } label: {
                    Circle()
                        .fill(.primary)
                        .frame(width: bloomDiameter(size), height: bloomDiameter(size))
                        .overlay(
                            Circle().stroke(.tint, lineWidth: selectedSize == size ? 3 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(size)".capitalized)
            }
        }
        .frame(height: 64, alignment: .center)
        .padding(12)
        .background(.regularMaterial, in: Capsule())
    }

    /// Preview dot for the bloom. The eraser and paintbrush are much larger in canvas
    /// space, so show them at a reduced scale (capped) — still visibly bigger than ink.
    private func bloomDiameter(_ size: BrushSize) -> CGFloat {
        let brush = bloomedBrush ?? selectedBrush
        let width = size.width(for: brush)
        let displayScale: CGFloat
        switch brush {
        case .eraser:     displayScale = 0.42
        case .paintbrush: displayScale = 0.7
        default:          displayScale = 1.5
        }
        return min(width * displayScale, 56)
    }
}

#Preview {
    @Previewable @State var brush: BrushKind = .pen
    @Previewable @State var size: BrushSize = .medium
    return BrushPicker(selectedBrush: $brush, selectedSize: $size)
        .padding()
}
