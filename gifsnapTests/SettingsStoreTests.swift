import XCTest
@testable import gifsnap

final class SettingsStoreTests: XCTestCase {
    var store: SettingsStore!

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: "com.joyson.gifsnap.test")!
        defaults.removePersistentDomain(forName: "com.joyson.gifsnap.test")
        store = SettingsStore(defaults: defaults)
    }

    func testDefaultFPS() {
        XCTAssertEqual(store.fps, 10)
    }

    func testDefaultMaxWidth() {
        XCTAssertEqual(store.maxWidth, 800)
    }

    func testDefaultLoopCount() {
        XCTAssertEqual(store.loopCount, 0)
    }

    func testDefaultSaveFolder() {
        let expected = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Screenshots")
        XCTAssertEqual(store.saveFolder, expected)
    }

    func testPersistsFPS() {
        store.fps = 24
        XCTAssertEqual(store.fps, 24)
    }

    func testClampsMaxWidth() {
        store.maxWidth = 9999
        XCTAssertEqual(store.maxWidth, 1600)
        store.maxWidth = 1
        XCTAssertEqual(store.maxWidth, 400)
    }

    func testClampsFPS() {
        store.fps = 100
        XCTAssertEqual(store.fps, 30)
        store.fps = 0
        XCTAssertEqual(store.fps, 5)
    }
}
