import XCTest
@testable import klip

final class KeyComboTests: XCTestCase {
    func testEncodesAndDecodes() throws {
        let combo = KeyCombo(keyCode: 5, modifiers: 0x100 | 0x200)
        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        XCTAssertEqual(decoded, combo)
    }

    func testDisplayStringIncludesAllModifiers() {
        let combo = KeyCombo(keyCode: 5, modifiers: KeyCombo.cmd | KeyCombo.shift | KeyCombo.option)
        XCTAssertTrue(combo.displayString.contains("⌘"))
        XCTAssertTrue(combo.displayString.contains("⇧"))
        XCTAssertTrue(combo.displayString.contains("⌥"))
        XCTAssertTrue(combo.displayString.contains("G"))
    }

    func testDisplayStringForFunctionKey() {
        let combo = KeyCombo(keyCode: 122, modifiers: 0)
        XCTAssertEqual(combo.displayString, "F1")
    }

    func testRequiresModifierIsFalseForBareKey() {
        let combo = KeyCombo(keyCode: 5, modifiers: 0)
        XCTAssertFalse(combo.hasRequiredModifier)
    }

    func testRequiresModifierIsTrueForCmd() {
        let combo = KeyCombo(keyCode: 5, modifiers: KeyCombo.cmd)
        XCTAssertTrue(combo.hasRequiredModifier)
    }

    func testDefaultScreenshotIsCmdShift2() {
        XCTAssertEqual(KeyCombo.defaultScreenshot.keyCode, 19)
        XCTAssertEqual(KeyCombo.defaultScreenshot.modifiers, KeyCombo.cmd | KeyCombo.shift)
    }

    func testDefaultGifIsCmdShiftG() {
        XCTAssertEqual(KeyCombo.defaultGif.keyCode, 5)
        XCTAssertEqual(KeyCombo.defaultGif.modifiers, KeyCombo.cmd | KeyCombo.shift)
    }
}
