import SwiftUI

struct PhotoSourceSheet: View {
    enum Source: String, Identifiable {
        case camera, library, starter
        var id: String { rawValue }
    }
    let onPick: (Source) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text("Where's your picture?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            HStack(spacing: 24) {
                tile(symbol: "camera.fill", label: "Camera") { onPick(.camera) }
                tile(symbol: "photo.fill",  label: "Photos") { onPick(.library) }
                tile(symbol: "star.fill",   label: "Starter") { onPick(.starter) }
            }
            Button("Never mind") { onCancel() }
                .font(.title3)
                .padding(.top, 8)
        }
        .padding(40)
        .presentationDetents([.medium])
    }

    private func tile(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .frame(width: 140, height: 140)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 24))
                Text(label).font(.title3.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview { PhotoSourceSheet(onPick: { _ in }, onCancel: {}) }
