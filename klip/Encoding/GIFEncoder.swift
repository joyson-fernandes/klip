import Foundation

enum GIFEncoderError: Error {
    case noFrames
    case gifskiNotFound
    case encodingFailed(Int32, String)
}

final class GIFEncoder {
    private let gifskiPath: String

    init(gifskiPath: String? = nil) {
        if let override = gifskiPath {
            self.gifskiPath = override
        } else {
            self.gifskiPath = Bundle.main.path(forResource: "gifski", ofType: nil)
                ?? Bundle.main.bundlePath + "/Contents/MacOS/gifski"
        }
    }

    func encode(
        framesDirectory: URL,
        outputURL: URL,
        fps: Int,
        maxWidth: Int,
        loopCount: Int
    ) throws {
        guard FileManager.default.fileExists(atPath: gifskiPath) else {
            throw GIFEncoderError.gifskiNotFound
        }
        let frames = try FileManager.default.contentsOfDirectory(
            at: framesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !frames.isEmpty else {
            throw GIFEncoderError.noFrames
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: gifskiPath)
        process.arguments = [
            "--fps", "\(fps)",
            "--width", "\(maxWidth)",
            "--quality", "100",
            "--motion-quality", "100",
            "--lossy-quality", "100",
            "--repeat", "\(loopCount)",
            "-o", outputURL.path
        ] + frames.map(\.path)

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "unknown error"
            throw GIFEncoderError.encodingFailed(process.terminationStatus, errorMessage)
        }
    }
}
