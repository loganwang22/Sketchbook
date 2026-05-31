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
}
