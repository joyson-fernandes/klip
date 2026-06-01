import AppKit
import CoreGraphics

enum ScreenshotCapture {
    /// Capture the given rect (AppKit global coords, y-up) on the supplied screen.
    /// Returns nil if Screen Recording permission isn't granted or capture failed.
    static func capture(rect: CGRect, screen: NSScreen) -> CGImage? {
        let screenFrame = screen.frame
        let cgRect = CGRect(
            x: rect.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        return CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }
}
