import AppKit

final class RecordingHUD {
    private var panel: NSPanel?
    private var timer: Timer?
    private var elapsed = 0
    private var label: NSTextField?

    func show(near rect: CGRect) {
        elapsed = 0
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = NSColor(white: 0.1, alpha: 0.9)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 17
        panel.contentView?.layer?.masksToBounds = true

        let container = NSView(frame: panel.contentView!.bounds)
        container.wantsLayer = true

        let dot = NSView(frame: CGRect(x: 12, y: 11, width: 12, height: 12))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dot.layer?.cornerRadius = 6
        container.addSubview(dot)

        let lbl = NSTextField(labelWithString: "00:00  ⌘⇧G to stop")
        lbl.frame = CGRect(x: 32, y: 8, width: 156, height: 18)
        lbl.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        lbl.textColor = .white
        container.addSubview(lbl)
        self.label = lbl

        panel.contentView?.addSubview(container)

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = rect.midX - 100 + screen.frame.minX
        let y = screen.frame.maxY - rect.minY + 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFront(nil)
        self.panel = panel

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed += 1
            let mins = self.elapsed / 60
            let secs = self.elapsed % 60
            self.label?.stringValue = String(format: "%02d:%02d  ⌘⇧G to stop", mins, secs)
        }
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        label = nil
        elapsed = 0
    }
}
