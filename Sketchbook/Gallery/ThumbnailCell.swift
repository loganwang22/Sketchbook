import SwiftUI

struct ThumbnailCell: View {
    let image: UIImage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
        }
        .buttonStyle(.plain)
    }
}

/// The dashed "new page" tile. Used as the label of a menu (Drawing / Chinese writing).
struct NewDrawingTile: View {
    var body: some View {
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
            .accessibilityLabel("New page")
    }
}
