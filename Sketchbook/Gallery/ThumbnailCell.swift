import SwiftUI

struct ThumbnailCell: View {
    let image: UIImage?
    let isWiggling: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var wigglePhase: Double = 0

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                    }
                }
                .frame(width: 220, height: 165)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.1)))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                if isWiggling {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .background(Circle().fill(.white))
                    }
                    .offset(x: 6, y: -6)
                }
            }
            .rotationEffect(.degrees(isWiggling ? sin(wigglePhase) * 1.5 : 0))
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.linear(duration: 0.2).repeatForever(autoreverses: false)) {
                wigglePhase = .pi * 2
            }
        }
    }
}

struct NewDrawingTile: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 18)
                .fill(.tint.opacity(0.1))
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(.tint)
                )
                .frame(width: 220, height: 165)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.tint.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New drawing")
    }
}
