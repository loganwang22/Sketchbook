import SwiftUI
import UIKit

/// A photo drawn as a full-bleed, aspect-fit layer behind or in front of the canvas.
/// `multiplyBlend` makes white pixels read as transparent (used for the colour-in
/// line-art overlay, so the child's colours show through and only the black lines stay).
struct PhotoLayerView: UIViewRepresentable {
    let image: UIImage
    let opacity: Double
    var multiplyBlend: Bool = false

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.alpha = CGFloat(opacity)
        view.isUserInteractionEnabled = false
        applyBlend(to: view)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.image = image
        view.alpha = CGFloat(opacity)
        applyBlend(to: view)
    }

    private func applyBlend(to view: UIImageView) {
        view.layer.compositingFilter = multiplyBlend ? "multiplyBlendMode" : nil
    }

    // Without this, SwiftUI uses the image's intrinsic point size — a camera shot
    // (e.g. 4032×3024) blows up the parent ZStack and pushes the chrome off-screen.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}
