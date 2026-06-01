import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Extracts a photo's contour as black lines on a *transparent* background, so it can
/// overlay the canvas without covering the paper colour. Used for both colour-in (bold,
/// on top) and trace (faint, below the strokes).
/// Pipeline: greyscale → edge detect → contrast → luminance-to-alpha → recolour to black.
enum ColoringPageFilter {
    static func lineArt(from input: UIImage) -> UIImage? {
        guard let ciInput = CIImage(image: input) else { return nil }
        let context = CIContext(options: nil)

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = ciInput
        guard let monoOutput = mono.outputImage else { return nil }

        // Bright edges on a black background.
        let edges = CIFilter.edges()
        edges.inputImage = monoOutput
        edges.intensity = 6.0
        guard let edgesOutput = edges.outputImage else { return nil }

        // Sharpen so faint edges drop out and real lines stay crisp.
        let contrast = CIFilter.colorControls()
        contrast.inputImage = edgesOutput
        contrast.brightness = 0.0
        contrast.contrast = 2.5
        contrast.saturation = 0
        guard let contrastOutput = contrast.outputImage else { return nil }

        // Turn luminance into alpha: bright lines become opaque, black background clears.
        let mask = CIFilter.maskToAlpha()
        mask.inputImage = contrastOutput
        guard let maskOutput = mask.outputImage else { return nil }

        // Recolour the (white) lines to black while keeping the alpha mask.
        let recolor = CIFilter.colorMatrix()
        recolor.inputImage = maskOutput
        recolor.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        recolor.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        recolor.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        recolor.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        recolor.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)

        guard let finalOutput = recolor.outputImage,
              let cgImage = context.createCGImage(finalOutput, from: ciInput.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: input.scale, orientation: input.imageOrientation)
    }
}
