import SwiftUI

struct PhotoModeSheet: View {
    let preview: UIImage
    let onPick: (PhotoLayer.Mode) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("How do you want to use this?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Image(uiImage: preview)
                .resizable().scaledToFit()
                .frame(maxHeight: 180)
                .cornerRadius(16)
            HStack(spacing: 20) {
                modeTile(symbol: "eye.fill",   label: "Look at it",  mode: .reference)
                modeTile(symbol: "pencil",     label: "Trace it",    mode: .trace)
                modeTile(symbol: "paintbrush", label: "Colour it in", mode: .coloringPage)
            }
            Button("Never mind") { onCancel() }.font(.title3)
        }
        .padding(40)
        .presentationDetents([.large])
    }

    private func modeTile(symbol: String, label: String, mode: PhotoLayer.Mode) -> some View {
        Button { onPick(mode) } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .frame(width: 120, height: 120)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 22))
                Text(label).font(.title3.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
    }
}
