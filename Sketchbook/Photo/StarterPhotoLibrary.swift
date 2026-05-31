import SwiftUI
import UIKit

enum StarterPhotoLibrary {
    struct Starter: Identifiable {
        let id: String
        let symbol: String
        let displayName: String
    }

    static let starters: [Starter] = [
        Starter(id: "pawprint", symbol: "pawprint.fill",  displayName: "Paw"),
        Starter(id: "bird",     symbol: "bird.fill",      displayName: "Bird"),
        Starter(id: "fish",     symbol: "fish.fill",      displayName: "Fish"),
        Starter(id: "car",      symbol: "car.fill",       displayName: "Car"),
        Starter(id: "house",    symbol: "house.fill",     displayName: "House"),
        Starter(id: "leaf",     symbol: "leaf.fill",      displayName: "Leaf"),
    ]

    /// Render an SF symbol to a 512×512 UIImage at heavy weight, so it survives downstream
    /// processing (e.g. ColoringPageFilter) and looks like real artwork on the canvas.
    static func image(for starter: Starter) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 380, weight: .regular)
        guard let symbolImage = UIImage(systemName: starter.symbol, withConfiguration: config) else {
            return nil
        }
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let tinted = symbolImage.withTintColor(.black, renderingMode: .alwaysOriginal)
            let imageSize = tinted.size
            let origin = CGPoint(x: (size.width - imageSize.width) / 2,
                                 y: (size.height - imageSize.height) / 2)
            tinted.draw(at: origin)
        }
    }
}

struct StarterPhotoGrid: View {
    let onPick: (UIImage) -> Void
    let onCancel: () -> Void

    private let columns = Array(repeating: GridItem(.fixed(140), spacing: 16), count: 3)

    var body: some View {
        VStack(spacing: 16) {
            Text("Pick a starter picture")
                .font(.title.weight(.semibold))
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(StarterPhotoLibrary.starters) { starter in
                    if let img = StarterPhotoLibrary.image(for: starter) {
                        Button { onPick(img) } label: {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(starter.displayName)
                    }
                }
            }
            Button("Never mind") { onCancel() }.font(.title3).padding(.top, 8)
        }
        .padding(32)
        .presentationDetents([.large])
    }
}
