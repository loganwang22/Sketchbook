import SwiftUI

struct ColorPalette: View {
    @Binding var selectedColor: ColorRGBA
    @State private var customColor: ColorRGBA?
    @State private var showingWheel = false
    @State private var wheelTarget: ColorRGBA = .init(r: 0, g: 0, b: 0)

    var body: some View {
        HStack(spacing: 6) {
            ForEach(KidPalette.colors, id: \.name) { entry in
                colorChip(entry.color, name: entry.name)
            }
            if let custom = customColor {
                colorChip(custom, name: "Custom")
            } else {
                Button { wheelTarget = selectedColor; showingWheel = true } label: {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 24))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("More colors")
            }
        }
        .sheet(isPresented: $showingWheel) {
            colorWheelSheet
        }
    }

    private func colorChip(_ color: ColorRGBA, name: String) -> some View {
        let isSelected = (color == selectedColor)
        return Circle()
            .fill(color.swiftUIColor)
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(.primary, lineWidth: isSelected ? 3 : 1))
            .onTapGesture { selectedColor = color }
            .onLongPressGesture(minimumDuration: 0.4) {
                wheelTarget = color
                showingWheel = true
            }
            .accessibilityLabel(name)
    }

    private var colorWheelSheet: some View {
        VStack(spacing: 24) {
            Text("Pick any colour")
                .font(.title2.weight(.semibold))
            ColorPicker("", selection: Binding(
                get: { wheelTarget.swiftUIColor },
                set: { wheelTarget = ColorRGBA($0) }
            ), supportsOpacity: false)
            .labelsHidden()
            .scaleEffect(2.0)
            .frame(height: 200)
            Button {
                customColor = wheelTarget
                selectedColor = wheelTarget
                showingWheel = false
            } label: {
                Text("Use this colour")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(wheelTarget.swiftUIColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(48)
        .presentationDetents([.medium])
    }
}

#Preview {
    @Previewable @State var color = KidPalette.colors[0].color
    return ColorPalette(selectedColor: $color).padding()
}
