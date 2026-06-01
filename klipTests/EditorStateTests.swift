import XCTest
import AppKit
@testable import klip

final class EditorStateTests: XCTestCase {
    func testAppendsAnnotation() {
        let s = EditorState(image: dummy())
        s.append(ArrowAnnotation(start: .zero, end: CGPoint(x: 10, y: 10), color: .red, width: 3))
        XCTAssertEqual(s.annotations.count, 1)
    }

    func testUndoRemovesLastAnnotation() {
        let s = EditorState(image: dummy())
        s.append(ArrowAnnotation(start: .zero, end: CGPoint(x: 10, y: 10), color: .red, width: 3))
        s.undo()
        XCTAssertEqual(s.annotations.count, 0)
    }

    func testRedoRestoresUndone() {
        let s = EditorState(image: dummy())
        s.append(ArrowAnnotation(start: .zero, end: CGPoint(x: 10, y: 10), color: .red, width: 3))
        s.undo()
        s.redo()
        XCTAssertEqual(s.annotations.count, 1)
    }

    func testNewAppendClearsRedoStack() {
        let s = EditorState(image: dummy())
        s.append(ArrowAnnotation(start: .zero, end: CGPoint(x: 10, y: 10), color: .red, width: 3))
        s.undo()
        s.append(RectAnnotation(rect: CGRect(x: 0, y: 0, width: 5, height: 5), color: .blue, width: 2))
        s.redo()
        XCTAssertEqual(s.annotations.count, 1)
        XCTAssertTrue(s.annotations.first is RectAnnotation)
    }

    func testStepCounterAutoIncrements() {
        let s = EditorState(image: dummy())
        let a = StepAnnotation(center: .zero, color: .red, number: s.nextStepNumber())
        s.append(a)
        let b = StepAnnotation(center: CGPoint(x: 10, y: 10), color: .red, number: s.nextStepNumber())
        s.append(b)
        XCTAssertEqual(a.number, 1)
        XCTAssertEqual(b.number, 2)
    }

    private func dummy() -> CGImage {
        let ctx = CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }
}
