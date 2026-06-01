import SwiftUI

struct ColorPalette: View {
    @Binding var palette: [ColorRGBA]
    @Binding var selectedColor: ColorRGBA
    @State private var editing: EditSlot?

    /// Identifies which swatch the colour wheel is editing.
    private struct EditSlot: Identifiable { let index: Int; var id: Int { index } }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(palette.indices, id: \.self) { index in
                colorChip(index)
            }
        }
        .sheet(item: $editing) { slot in
            ColorWheelSheet(
                initial: palette[slot.index],
                onUse: { newColor in
                    palette[slot.index] = newColor
                    selectedColor = newColor
                    editing = nil
                },
                onCancel: { editing = nil }
            )
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

/// Full colour wheel for re-defining a single palette swatch.
private struct ColorWheelSheet: View {
    let initial: ColorRGBA
    let onUse: (ColorRGBA) -> Void
    let onCancel: () -> Void
    @State private var working: Color

    init(initial: ColorRGBA, onUse: @escaping (ColorRGBA) -> Void, onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onUse = onUse
        self.onCancel = onCancel
        _working = State(initialValue: initial.swiftUIColor)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Pick any colour")
                .font(.title2.weight(.semibold))
            ColorPicker("", selection: $working, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(2.0)
                .frame(height: 160)
            HStack(spacing: 16) {
                Button("Cancel") { onCancel() }
                    .font(.title3)
                Button { onUse(ColorRGBA(working)) } label: {
                    Text("Use this colour")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(working, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(48)
        .presentationDetents([.medium])
    }
}

#Preview {
    @Previewable @State var palette = KidPalette.colors.map(\.color)
    @Previewable @State var color = KidPalette.colors[0].color
    return ColorPalette(palette: $palette, selectedColor: $color).padding()
}
