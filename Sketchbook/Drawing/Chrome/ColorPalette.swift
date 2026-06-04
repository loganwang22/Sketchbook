import SwiftUI

struct ColorPalette: View {
    @Binding var palette: [ColorRGBA]
    @Binding var selectedColor: ColorRGBA
    @State private var editing: EditSlot?

    /// Identifies which swatch the colour picker is editing.
    private struct EditSlot: Identifiable { let index: Int; var id: Int { index } }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(palette.indices, id: \.self) { index in
                colorChip(index)
            }
        }
        .sheet(item: $editing) { slot in
            // Custom single-panel picker (spectrum + H/S/L bars). Editing updates the
            // swatch and the active colour live.
            ColorEditor(
                color: Binding(
                    get: { palette[slot.index] },
                    set: { newColor in
                        palette[slot.index] = newColor
                        selectedColor = newColor
                    }
                ),
                onFinish: { editing = nil }
            )
            .presentationDetents([.height(540)])
            .presentationDragIndicator(.visible)
        }
    }

    private func colorChip(_ index: Int) -> some View {
        let color = palette[index]
        let isSelected = (color == selectedColor)
        return Circle()
            .fill(color.swiftUIColor)
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(.primary, lineWidth: isSelected ? 3 : 1))
            .contentShape(Circle())
            .onTapGesture { selectedColor = color }
            .onLongPressGesture(minimumDuration: 0.4) { editing = EditSlot(index: index) }
            .accessibilityLabel("Colour \(index + 1)")
            .accessibilityHint("Tap to use. Touch and hold to change this colour.")
    }
}

#Preview {
    @Previewable @State var palette = KidPalette.colors.map(\.color)
    @Previewable @State var color = KidPalette.colors[0].color
    return ColorPalette(palette: $palette, selectedColor: $color).padding()
}
