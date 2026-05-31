import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Converts a photograph into a black-line-on-white "coloring page" image.
/// Pipeline: greyscale → edge detect → invert → contrast threshold.
enum ColoringPageFilter {
    static func apply(to input: UIImage) -> UIImage? {
        guard let ciInput = CIImage(image: input) else { return nil }
        let context = CIContext(options: nil)

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = ciInput
        guard let monoOutput = mono.outputImage else { return nil }

        let edges = CIFilter.edges()
        edges.inputImage = monoOutput
        edges.intensity = 5.0
        guard let edgesOutput = edges.outputImage else { return nil }

        let invert = CIFilter.colorInvert()
        invert.inputImage = edgesOutput
        guard let invertedOutput = invert.outputImage else { return nil }

        let contrast = CIFilter.colorControls()
        contrast.inputImage = invertedOutput
        contrast.brightness = 0.2
        contrast.contrast = 4.0
        contrast.saturation = 0
        guard let finalOutput = contrast.outputImage,
              let cgImage = context.createCGImage(finalOutput, from: ciInput.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: input.scale, orientation: input.imageOrientation)
    }
}
