import SwiftUI

/// Bottom dock: the stroke-size bar, then colours, then the photo button. Brushes now
/// live in the left `BrushRail`, not here.
struct ToolDock: View {
    @Binding var widthFraction: Double
    @Binding var color: ColorRGBA
    @Binding var palette: [ColorRGBA]
    let onPhotoTap: () -> Void
    /// Chinese writing mode hides the photo button.
    var writingMode: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            StrokeWidthBar(fraction: $widthFraction, tint: color.swiftUIColor)
            Divider().frame(height: 40)
            ColorPalette(palette: $palette, selectedColor: $color)
            if !writingMode {
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
    @Previewable @State var width = 0.4
    @Previewable @State var color = KidPalette.colors[9].color
    @Previewable @State var palette = KidPalette.colors.map(\.color)
    return ToolDock(widthFraction: $width, color: $color, palette: $palette, onPhotoTap: {})
}
