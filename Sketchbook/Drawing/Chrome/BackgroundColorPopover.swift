import SwiftUI

struct BackgroundColorPopover: View {
    @Binding var selectedColor: ColorRGBA
    let onClose: () -> Void

    private var options: [(name: String, color: ColorRGBA)] {
        KidPalette.colors.map { ($0.name, $0.color) }
        + [("White", ColorRGBA(r: 1, g: 1, b: 1))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Background")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(48)), count: 6), spacing: 12) {
                ForEach(options, id: \.name) { entry in
                    Circle()
                        .fill(entry.color.swiftUIColor)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(.primary, lineWidth: selectedColor == entry.color ? 3 : 1))
                        .onTapGesture {
                            selectedColor = entry.color
                            onClose()
                        }
                        .accessibilityLabel(entry.name)
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(260)])
    }
}

#Preview {
    @Previewable @State var c = ColorRGBA(r: 1, g: 1, b: 1)
    return BackgroundColorPopover(selectedColor: $c, onClose: {})
}
