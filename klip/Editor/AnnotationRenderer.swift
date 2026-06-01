import AppKit
import CoreGraphics

enum AnnotationRenderer {
    /// Flatten image + annotations into a single PNG.
    /// - Parameter cropRect: if provided (in image coordinates), the output is cropped to that rect.
    static func flatten(image: CGImage, annotations: [Annotation], cropRect: CGRect? = nil) -> Data? {
        let width = image.width
        let height = image.height
        let space = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for ann in annotations {
            ann.draw(in: ctx)
        }
        guard let full = ctx.makeImage() else { return nil }

        let finalImage: CGImage
        if let cropRect = cropRect {
            // Canvas uses y-up (origin at bottom-left); CGImage.cropping uses y-down
            // (origin at top-left). Flip Y so the user-selected region is what's saved.
            let flipped = CGRect(
                x: cropRect.minX,
                y: CGFloat(full.height) - cropRect.maxY,
                width: cropRect.width,
                height: cropRect.height
            )
            finalImage = full.cropping(to: flipped) ?? full
        } else {
            finalImage = full
        }

        let rep = NSBitmapImageRep(cgImage: finalImage)
        return rep.representation(using: .png, properties: [:])
    }
}
