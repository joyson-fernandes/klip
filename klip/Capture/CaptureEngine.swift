import ScreenCaptureKit
import CoreMedia
import AppKit
import ImageIO

protocol CaptureEngineDelegate: AnyObject {
    func captureEngineDidFinish(_ engine: CaptureEngine, framesDirectory: URL)
    func captureEngineDidFail(_ engine: CaptureEngine, error: Error)
}

final class CaptureEngine: NSObject {
    weak var delegate: CaptureEngineDelegate?
    private var stream: SCStream?
    private var framesDirectory: URL?
    private var frameIndex = 0
    private let queue = DispatchQueue(label: "com.joyson.klip.capture")

    func start(rect: CGRect, screen: NSScreen, fps: Int) async throws {
        let framesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("klip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
        framesDirectory = framesDir
        frameIndex = 0

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        // Match SCDisplay to the NSScreen we captured the selection on
        let screenID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        guard let display = content.displays.first(where: { $0.displayID == screenID }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        // ScreenCaptureKit uses pixel-space coordinates. Convert from points using the screen's scale.
        let scale = screen.backingScaleFactor
        let screenFrame = screen.frame
        // Convert AppKit (y-up, global) to display-local (y-down) coords in points first.
        let localX = rect.minX - screenFrame.minX
        let localY = screenFrame.maxY - rect.maxY
        let sourceRectPixels = CGRect(
            x: localX * scale,
            y: localY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        let config = SCStreamConfiguration()
        config.sourceRect = sourceRectPixels
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.queueDepth = 6
        config.showsCursor = true

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
    }

    func stop() async {
        guard let stream = stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        // Let in-flight frames finish writing on the capture queue before notifying
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
        if let dir = framesDirectory {
            delegate?.captureEngineDidFinish(self, framesDirectory: dir)
        }
    }
}

extension CaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusRaw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRaw),
              status == .complete,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
              let framesDir = framesDirectory else { return }

        let idx = frameIndex
        frameIndex += 1
        let framePath = framesDir.appendingPathComponent(String(format: "frame-%04d.png", idx))

        guard let dest = CGImageDestinationCreateWithURL(framePath as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
    }
}

extension CaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        delegate?.captureEngineDidFail(self, error: error)
    }
}

enum CaptureError: Error {
    case noDisplay
}
