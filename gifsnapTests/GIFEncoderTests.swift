import XCTest
@testable import gifsnap

final class GIFEncoderTests: XCTestCase {
    var encoder: GIFEncoder!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        encoder = GIFEncoder(gifskiPath: "/Users/joyson/gifsnap/Resources/gifski")
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testEncodesFramesToGIF() throws {
        // Minimal valid 1x1 PNG
        let png1x1 = Data([
            0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,
            0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,
            0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01,
            0x08,0x02,0x00,0x00,0x00,0x90,0x77,0x53,
            0xDE,0x00,0x00,0x00,0x0C,0x49,0x44,0x41,
            0x54,0x08,0xD7,0x63,0xF8,0xFF,0xFF,0x3F,
            0x00,0x05,0xFE,0x02,0xFE,0xDC,0xCC,0x59,
            0xE7,0x00,0x00,0x00,0x00,0x49,0x45,0x4E,
            0x44,0xAE,0x42,0x60,0x82
        ])
        for i in 1...3 {
            let framePath = tempDir.appendingPathComponent(String(format: "frame-%04d.png", i))
            try png1x1.write(to: framePath)
        }
        let outputURL = tempDir.appendingPathComponent("output.gif")
        try encoder.encode(framesDirectory: tempDir, outputURL: outputURL, fps: 10, maxWidth: 800, loopCount: 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let data = try Data(contentsOf: outputURL)
        XCTAssertTrue(data.prefix(6) == Data("GIF89a".utf8) || data.prefix(6) == Data("GIF87a".utf8))
    }

    func testThrowsWhenNoFrames() {
        let outputURL = tempDir.appendingPathComponent("output.gif")
        let badEncoder = GIFEncoder(gifskiPath: "/nonexistent/gifski")
        XCTAssertThrowsError(
            try badEncoder.encode(framesDirectory: tempDir, outputURL: outputURL, fps: 10, maxWidth: 800, loopCount: 0)
        )
    }
}
