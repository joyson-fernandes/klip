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
        // Dim the whole screen, then cut a hole for the selection
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard selectionRect.width > 0, selectionRect.height > 0 else { return }

        // Clear the selected region
        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        // Purple border
        let purple = NSColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1)
        purple.setStroke()
        let border = NSBezierPath(rect: selectionRect)
        border.lineWidth = 2
        border.stroke()

        // Dimensions badge (above the selection, falls back to inside if near top edge)
        let labelText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
        ]
        let str = NSAttributedString(string: " \(labelText) ", attributes: attrs)
        let textSize = str.size()
        let badgeRect = NSRect(
            x: selectionRect.minX,
            y: selectionRect.maxY + 4,
            width: textSize.width,
            height: textSize.height + 2
        )
        purple.setFill()
        badgeRect.fill()
        str.draw(at: CGPoint(x: badgeRect.minX, y: badgeRect.minY + 1))
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
