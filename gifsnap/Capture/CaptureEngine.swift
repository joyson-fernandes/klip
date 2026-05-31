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
    private let queue = DispatchQueue(label: "com.joyson.gifsnap.capture")

    func start(rect: CGRect, screen: NSScreen, fps: Int) async throws {
        let framesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gifsnap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
        framesDirectory = framesDir
        frameIndex = 0

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = convertToDisplayCoordinates(rect, screen: screen)
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.queueDepth = 5

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
    }

    func stop() async {
        guard let stream = stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        if let dir = framesDirectory {
            delegate?.captureEngineDidFinish(self, framesDirectory: dir)
        }
    }

    private func convertToDisplayCoordinates(_ rect: CGRect, screen: NSScreen) -> CGRect {
        let screenFrame = screen.frame
        let y = screenFrame.maxY - rect.maxY
        return CGRect(x: rect.minX - screenFrame.minX, y: y, width: rect.width, height: rect.height)
    }
}

extension CaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let idx = frameIndex
        frameIndex += 1
        let framePath = framesDirectory!.appendingPathComponent(String(format: "frame-%04d.png", idx))

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
