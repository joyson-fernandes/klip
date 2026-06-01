import XCTest
import AppKit
@testable import klip

final class AnnotationRendererTests: XCTestCase {
    func testFlattensWhiteImageWithRedArrowToPNGContainingRedPixels() {
        let image = solidImage(color: .white, width: 100, height: 100)
        let arrow = ArrowAnnotation(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 90, y: 90), color: .red, width: 4)
        let pngData = AnnotationRenderer.flatten(image: image, annotations: [arrow])
        guard let pngData else { return XCTFail("no png") }
        XCTAssertGreaterThan(pngData.count, 0)

        let rep = NSBitmapImageRep(data: pngData)!
        var foundRed = false
        for i in 10...90 {
            if let color = rep.colorAt(x: i, y: 100 - i),
               color.redComponent > 0.7, color.greenComponent < 0.3, color.blueComponent < 0.3 {
                foundRed = true; break
            }
        }
        XCTAssertTrue(foundRed)
    }

    private func solidImage(color: NSColor, width: Int, height: Int) -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}
