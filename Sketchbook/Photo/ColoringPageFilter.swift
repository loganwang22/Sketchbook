import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Extracts a photo's contour as black lines on a *transparent* background, so it can
/// overlay the canvas without covering the paper colour. Used for both colour-in (bold,
/// on top) and trace (faint, below the strokes).
enum ColoringPageFilter {
    // Tunables — raise edgeIntensity / lower threshold for more lines; raise thickenRadius
    // for bolder lines; raise denoiseRadius to drop camera speckle.
    private static let denoiseRadius: Double = 1.0
    private static let edgeIntensity: Double = 9.0
    private static let lineThreshold: Float = 0.15
    private static let thickenRadius: Double = 1.2

    static func lineArt(from input: UIImage) -> UIImage? {
        guard let ciInput = CIImage(image: input) else { return nil }
        let extent = ciInput.extent
        let context = CIContext(options: nil)

        // Clamp first so edge detection doesn't see the image border as an edge — that
        // boundary artifact was the "annoying border" around starter/camera pictures.
        var image = ciInput.clampedToExtent()

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = image
        guard let monoOut = mono.outputImage else { return nil }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = monoOut
        blur.radius = Float(denoiseRadius)
        image = blur.outputImage ?? monoOut

        let edges = CIFilter.edges()
        edges.inputImage = image
        edges.intensity = Float(edgeIntensity)
        guard let edgesOut = edges.outputImage else { return nil }

        // Crisp binary: strong edges -> white lines, everything else -> black.
        let threshold = CIFilter.colorThreshold()
        threshold.inputImage = edgesOut
        threshold.threshold = lineThreshold
        guard let thresholdOut = threshold.outputImage else { return nil }

        // Thicken the lines so the contour reads boldly.
        let thicken = CIFilter.morphologyMaximum()
        thicken.inputImage = thresholdOut
        thicken.radius = Float(thickenRadius)
        let thickenedOut = thicken.outputImage ?? thresholdOut

        // White lines -> opaque, black -> transparent.
        let mask = CIFilter.maskToAlpha()
        mask.inputImage = thickenedOut
        guard let maskOut = mask.outputImage else { return nil }

        // Recolour the lines to black, keeping the alpha mask.
        let recolor = CIFilter.colorMatrix()
        recolor.inputImage = maskOut
        recolor.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        recolor.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        recolor.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        recolor.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        recolor.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)

        guard let finalOut = recolor.outputImage,
              let cgImage = context.createCGImage(finalOut, from: extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: input.scale, orientation: input.imageOrientation)
    }
}
