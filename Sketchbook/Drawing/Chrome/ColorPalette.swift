import SwiftUI
import UIKit

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
            // Opens straight into the system colour picker, pre-selected to the swatch's
            // current colour. Picking updates the swatch (and the active colour) live.
            SystemColorPicker(
                color: Binding(
                    get: { palette[slot.index] },
                    set: { newColor in
                        palette[slot.index] = newColor
                        selectedColor = newColor
                    }
                ),
                onFinish: { editing = nil }
            )
            .ignoresSafeArea()
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

/// Presents the iOS system colour picker directly, bound to a `ColorRGBA`.
private struct SystemColorPicker: UIViewControllerRepresentable {
    @Binding var color: ColorRGBA
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.selectedColor = color.uiColor
        picker.supportsAlpha = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIColorPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        let parent: SystemColorPicker
        init(_ parent: SystemColorPicker) { self.parent = parent }

        func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                       didSelect color: UIColor, continuously: Bool) {
            parent.color = ColorRGBA(Color(uiColor: color))
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            parent.onFinish()
        }
    }
}

#Preview {
    @Previewable @State var palette = KidPalette.colors.map(\.color)
    @Previewable @State var color = KidPalette.colors[0].color
    return ColorPalette(palette: $palette, selectedColor: $color).padding()
}
