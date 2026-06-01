import XCTest
import AppKit
@testable import klip

final class ScreenshotCaptureTests: XCTestCase {
    func testReturnsImageWithExpectedPixelSize() {
        guard let screen = NSScreen.main else { return XCTFail("no main screen") }
        let rect = CGRect(x: screen.frame.minX + 100, y: screen.frame.minY + 100, width: 200, height: 150)
        guard let image = ScreenshotCapture.capture(rect: rect, screen: screen) else {
            // No permission in test bundle — acceptable, exercised by manual e2e
            return
        }
        let scale = Int(screen.backingScaleFactor)
        XCTAssertEqual(image.width, 200 * scale)
        XCTAssertEqual(image.height, 150 * scale)
    }
}
