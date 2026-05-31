import AppKit

protocol RegionSelectorDelegate: AnyObject {
    func regionSelector(_ selector: RegionSelector, didSelect rect: CGRect, on screen: NSScreen)
    func regionSelectorDidCancel(_ selector: RegionSelector)
}

final class RegionSelector: NSObject {
    weak var delegate: RegionSelectorDelegate?
    private var windows: [NSWindow] = []
    private var trackingWindow: NSWindow?
    private var startPoint: NSPoint?
    private var selectionView: SelectionOverlayView?

    func show() {
        for screen in NSScreen.screens {
            let window = makeOverlayWindow(for: screen)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSCursor.crosshair.push()
    }

    func dismiss() {
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        trackingWindow = nil
        selectionView = nil
        startPoint = nil
    }

    private func makeOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = NSColor.black.withAlphaComponent(0.4)
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.delegate = self

        let view = SelectionOverlayView(frame: screen.frame)
        view.onMouseDown = { [weak self] point in self?.handleMouseDown(point, in: window, screen: screen) }
        view.onMouseDragged = { [weak self] point in self?.handleMouseDragged(point) }
        view.onMouseUp = { [weak self] point in self?.handleMouseUp(point, screen: screen) }
        view.onKeyDown = { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.dismiss()
                self?.delegate?.regionSelectorDidCancel(self!)
            }
        }
        window.contentView = view
        window.makeFirstResponder(view)
        return window
    }

    private func handleMouseDown(_ point: NSPoint, in window: NSWindow, screen: NSScreen) {
        startPoint = point
        trackingWindow = window
        selectionView = window.contentView as? SelectionOverlayView
    }

    private func handleMouseDragged(_ point: NSPoint) {
        guard let start = startPoint,
              let window = trackingWindow,
              let view = window.contentView as? SelectionOverlayView else { return }
        let rect = CGRect(
            x: min(start.x, point.x), y: min(start.y, point.y),
            width: abs(point.x - start.x), height: abs(point.y - start.y)
        )
        view.selectionRect = rect
    }

    private func handleMouseUp(_ point: NSPoint, screen: NSScreen) {
        guard let start = startPoint else { return }
        let rect = CGRect(
            x: min(start.x, point.x), y: min(start.y, point.y),
            width: abs(point.x - start.x), height: abs(point.y - start.y)
        )
        guard rect.width > 10 && rect.height > 10 else { dismiss(); return }
        dismiss()
        delegate?.regionSelector(self, didSelect: rect, on: screen)
    }
}

extension RegionSelector: NSWindowDelegate {}

final class SelectionOverlayView: NSView {
    var onMouseDown: ((NSPoint) -> Void)?
    var onMouseDragged: ((NSPoint) -> Void)?
    var onMouseUp: ((NSPoint) -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?

    var selectionRect: CGRect = .zero {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard selectionRect != .zero else { return }
        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)
        NSColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1).setStroke()
        let border = NSBezierPath(rect: selectionRect)
        border.lineWidth = 2
        border.stroke()
        let label = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .backgroundColor: NSColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1)
        ]
        let str = NSAttributedString(string: " \(label) ", attributes: attrs)
        str.draw(at: CGPoint(x: selectionRect.minX, y: selectionRect.maxY + 4))
    }

    override func mouseDown(with event: NSEvent) { onMouseDown?(convert(event.locationInWindow, from: nil)) }
    override func mouseDragged(with event: NSEvent) { onMouseDragged?(convert(event.locationInWindow, from: nil)) }
    override func mouseUp(with event: NSEvent) { onMouseUp?(convert(event.locationInWindow, from: nil)) }
    override func keyDown(with event: NSEvent) { onKeyDown?(event) }
}
