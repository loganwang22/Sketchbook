import SwiftUI
import UIKit

struct PhotoLayerView: UIViewRepresentable {
    let image: UIImage
    let opacity: Double
    let transform: CGAffineTransform

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.alpha = CGFloat(opacity)
        view.transform = transform
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.image = image
        view.alpha = CGFloat(opacity)
        view.transform = transform
    }

    // Without this, SwiftUI uses the image's intrinsic point size — a camera shot
    // (e.g. 4032×3024) blows up the parent ZStack and pushes the chrome off-screen.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}
