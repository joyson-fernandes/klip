import XCTest
@testable import klip

final class HotkeyManagerTests: XCTestCase {
    func testRegistersTwoHotkeys() {
        let mgr = HotkeyManager()
        let result = mgr.bind(
            screenshot: KeyCombo(keyCode: 19, modifiers: KeyCombo.cmd | KeyCombo.shift),
            gif: KeyCombo(keyCode: 5, modifiers: KeyCombo.cmd | KeyCombo.shift)
        ) {_ in}
        XCTAssertTrue(result.screenshotRegistered)
        XCTAssertTrue(result.gifRegistered)
        mgr.unbindAll()
    }

    func testReportsFailedRegistrationWithNilCombo() {
        let mgr = HotkeyManager()
        let result = mgr.bind(screenshot: nil, gif: nil) {_ in}
        XCTAssertFalse(result.screenshotRegistered)
        XCTAssertFalse(result.gifRegistered)
    }

    func testRebindReplacesRegistrations() {
        let mgr = HotkeyManager()
        _ = mgr.bind(
            screenshot: KeyCombo(keyCode: 19, modifiers: KeyCombo.cmd | KeyCombo.shift),
            gif: KeyCombo(keyCode: 5, modifiers: KeyCombo.cmd | KeyCombo.shift)
        ) {_ in}
        let result = mgr.bind(
            screenshot: KeyCombo(keyCode: 7, modifiers: KeyCombo.cmd | KeyCombo.option),
            gif: nil
        ) {_ in}
        XCTAssertTrue(result.screenshotRegistered)
        XCTAssertFalse(result.gifRegistered)
        mgr.unbindAll()
    }
}
