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
            Image(systemName: brush.displaySymbol)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear),
                            in: Circle())
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .offset(y: isSelected ? -6 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(brush.rawValue.capitalized)
    }

    private var sizeBloom: some View {
        HStack(spacing: 16) {
            ForEach(BrushSize.allCases) { size in
                Button { selectedSize = size; bloomedBrush = nil } label: {
                    Circle()
                        .fill(.primary)
                        .frame(width: CGFloat(size.rawValue) * 1.5,
                               height: CGFloat(size.rawValue) * 1.5)
                        .overlay(
                            Circle().stroke(.tint, lineWidth: selectedSize == size ? 3 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(size)".capitalized)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    @Previewable @State var brush: BrushKind = .pen
    @Previewable @State var size: BrushSize = .medium
    return BrushPicker(selectedBrush: $brush, selectedSize: $size)
        .padding()
}
