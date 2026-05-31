import XCTest
@testable import klip

final class OutputHandlerTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSavesGIFToFolder() throws {
        let gifData = Data("GIF89a fake".utf8)
        let sourceURL = tempDir.appendingPathComponent("source.gif")
        try gifData.write(to: sourceURL)
        let saveFolder = tempDir.appendingPathComponent("Saved")
        try FileManager.default.createDirectory(at: saveFolder, withIntermediateDirectories: true)
        let handler = OutputHandler()
        let savedURL = try handler.save(gifURL: sourceURL, to: saveFolder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(try Data(contentsOf: savedURL), gifData)
        XCTAssertTrue(savedURL.pathExtension == "gif")
    }

    func testSavedFilenameIncludesTimestamp() throws {
        let gifData = Data("GIF89a fake".utf8)
        let sourceURL = tempDir.appendingPathComponent("source.gif")
        try gifData.write(to: sourceURL)
        let saveFolder = tempDir.appendingPathComponent("Saved")
        try FileManager.default.createDirectory(at: saveFolder, withIntermediateDirectories: true)
        let handler = OutputHandler()
        let savedURL = try handler.save(gifURL: sourceURL, to: saveFolder)
        XCTAssertTrue(savedURL.lastPathComponent.hasPrefix("klip-"))
    }
}
