import SwiftUI

/// Vertical brush menu pinned to the left edge. All pens and brushes live here, softly
/// split into two groups (pen strokes, then artist brushes), with the eraser below.
struct BrushRail: View {
    @Binding var selectedBrush: BrushKind
    /// Chinese writing mode offers only the pen and the eraser.
    var writingMode: Bool = false

    private var pens: [BrushKind] {
        writingMode ? [.pen] : BrushKind.allCases.filter { $0.group == .pen }
    }
    private var brushes: [BrushKind] {
        writingMode ? [] : BrushKind.allCases.filter { $0.group == .brush }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(pens) { button($0) }
            if !brushes.isEmpty {
                softDivider
                ForEach(brushes) { button($0) }
            }
            softDivider
            button(.eraser)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, x: 2)
    }

    private var softDivider: some View {
        Capsule()
            .fill(.primary.opacity(0.12))
            .frame(width: 26, height: 2)
            .padding(.vertical, 2)
    }

    private func button(_ brush: BrushKind) -> some View {
        let isSelected = (brush == selectedBrush)
        return Button {
            selectedBrush = brush
        } label: {
            glyph(brush)
                .frame(width: 52, height: 52)
                // Selection shown by fill + ring only — no scaleEffect, which used to
                // enlarge the hit area and swallow taps meant for neighbouring brushes.
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.clear),
                            in: Circle())
                .overlay(Circle().stroke(.tint, lineWidth: isSelected ? 2.5 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(brush.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func glyph(_ brush: BrushKind) -> some View {
        switch brush.glyph {
        case .symbol(let name):
            Image(systemName: name).font(.system(size: 26, weight: .semibold))
        case .custom(let kind):
            CustomBrushIcon(kind: kind).frame(width: 28, height: 28)
        }
    }
}

#Preview {
    @Previewable @State var brush: BrushKind = .pen
    return BrushRail(selectedBrush: $brush).padding()
}
