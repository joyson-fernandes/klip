import AppKit
import CoreGraphics

enum AnnotationRenderer {
    static func flatten(image: CGImage, annotations: [Annotation]) -> Data? {
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
        guard let flat = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: flat)
        return rep.representation(using: .png, properties: [:])
    }
}
