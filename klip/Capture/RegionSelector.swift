import AppKit

protocol RegionSelectorDelegate: AnyObject {
    func regionSelector(_ selector: RegionSelector, didSelect rect: CGRect, on screen: NSScreen)
    func regionSelectorDidCancel(_ selector: RegionSelector)
}

/// Borderless windows can't become key by default — override so the overlay
/// receives keyboard events (Esc) and behaves predictably for mouse tracking.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class RegionSelector: NSObject {
    weak var delegate: RegionSelectorDelegate?
    private var windows: [OverlayWindow] = []
    private var trackingScreen: NSScreen?
    private var startPoint: NSPoint?

    func show() {
        // Make sure the app is active so mouse events route to our overlay reliably
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let window = makeOverlayWindow(for: screen)
            windows.append(window)
        }
        if let first = windows.first { first.makeKeyAndOrderFront(nil) }
        windows.dropFirst().forEach { $0.orderFront(nil) }
        NSCursor.crosshair.set()
    }

    func dismiss() {
        NSCursor.arrow.set()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        trackingScreen = nil
        startPoint = nil
    }

    private func makeOverlayWindow(for screen: NSScreen) -> OverlayWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.setFrame(screen.frame, display: true)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onMouseDown = { [weak self] point in
            self?.startPoint = point
            self?.trackingScreen = screen
            view.selectionRect = .zero
        }
        view.onMouseDragged = { [weak self] point in
            guard let start = self?.startPoint else { return }
            view.selectionRect = CGRect(
                x: min(start.x, point.x), y: min(start.y, point.y),
                width: abs(point.x - start.x), height: abs(point.y - start.y)
            )
        }
        view.onMouseUp = { [weak self] point in
            guard let self, let start = self.startPoint else { return }
            let rectInWindow = CGRect(
                x: min(start.x, point.x), y: min(start.y, point.y),
                width: abs(point.x - start.x), height: abs(point.y - start.y)
            )
            guard rectInWindow.width > 5, rectInWindow.height > 5 else {
                view.selectionRect = .zero
                self.startPoint = nil
                return
            }
            // Convert window-local rect to global screen coordinates (with origin in screen.frame)
            let globalRect = CGRect(
                x: rectInWindow.minX + screen.frame.minX,
                y: rectInWindow.minY + screen.frame.minY,
                width: rectInWindow.width,
                height: rectInWindow.height
            )
            self.dismiss()
            self.delegate?.regionSelector(self, didSelect: globalRect, on: screen)
        }
        view.onKeyDown = { [weak self] event in
            if event.keyCode == 53 { // Esc
                guard let self else { return }
                self.dismiss()
                self.delegate?.regionSelectorDidCancel(self)
            }
        }
        window.contentView = view
        window.initialFirstResponder = view
        DispatchQueue.main.async { window.makeFirstResponder(view) }
        return window
    }
}

final class SelectionOverlayView: NSView {
    var onMouseDown: ((NSPoint) -> Void)?
    var onMouseDragged: ((NSPoint) -> Void)?
    var onMouseUp: ((NSPoint) -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?

    var selectionRect: CGRect = .zero {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        guard selectionRect.width > 0, selectionRect.height > 0 else { return }

        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        NSColor.black.withAlphaComponent(0.6).setStroke()
        let outerPath = NSBezierPath(rect: selectionRect.insetBy(dx: -0.5, dy: -0.5))
        outerPath.lineWidth = 1
        outerPath.stroke()

        NSColor.white.setStroke()
        let innerPath = NSBezierPath(rect: selectionRect.insetBy(dx: 0.5, dy: 0.5))
        innerPath.lineWidth = 1
        innerPath.stroke()

        let labelText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ]
        let str = NSAttributedString(string: labelText, attributes: attrs)
        let strSize = str.size()
        let chipSize = NSSize(width: strSize.width + 16, height: strSize.height + 8)

        let yBelow = selectionRect.minY - chipSize.height - 6
        let useBelow = yBelow > 6
        let chipOrigin = NSPoint(
            x: selectionRect.maxX - chipSize.width,
            y: useBelow ? yBelow : selectionRect.maxY + 6
        )
        let chipRect = NSRect(origin: chipOrigin, size: chipSize)

        NSColor.black.withAlphaComponent(0.78).setFill()
        let chip = NSBezierPath(roundedRect: chipRect, xRadius: 4, yRadius: 4)
        chip.fill()
        str.draw(at: NSPoint(x: chipRect.minX + 8, y: chipRect.minY + 4))
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(convert(event.locationInWindow, from: nil))
    }
    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(convert(event.locationInWindow, from: nil))
    }
    override func mouseUp(with event: NSEvent) {
        onMouseUp?(convert(event.locationInWindow, from: nil))
    }
    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}
