import SwiftUI

struct ToolDock: View {
    @Binding var brush: BrushKind
    @Binding var size: BrushSize
    @Binding var color: ColorRGBA
    @Binding var palette: [ColorRGBA]
    let onPhotoTap: () -> Void
    /// Chinese writing mode: only the colour palette (pen is locked, no brushes/photos).
    var colorsOnly: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            if colorsOnly {
                ColorPalette(palette: $palette, selectedColor: $color)
            } else {
                BrushPicker(selectedBrush: $brush, selectedSize: $size)
                Divider().frame(height: 40)
                ColorPalette(palette: $palette, selectedColor: $color)
                Divider().frame(height: 40)
                Button(action: onPhotoTap) {
                    Image(systemName: "camera.fill.badge.ellipsis")
                        .font(.system(size: 26, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .background(.tint.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Add photo")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}

#Preview {
    @Previewable @State var brush: BrushKind = .pen
    @Previewable @State var size: BrushSize = .medium
    @Previewable @State var color = KidPalette.colors[9].color
    @Previewable @State var palette = KidPalette.colors.map(\.color)
    return ToolDock(brush: $brush, size: $size, color: $color, palette: $palette, onPhotoTap: {})
}
