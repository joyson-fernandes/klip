import AppKit

final class QuickAccessThumb {
    private var panel: NSPanel?
    private var fadeTimer: Timer?
    private var urlBox: URL?

    func show(fileURL: URL, preview: CGImage?) {
        hide()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let blur = NSVisualEffectView(frame: panel.contentView!.bounds)
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 10
        blur.layer?.masksToBounds = true

        if let preview = preview {
            let imageView = NSImageView(frame: blur.bounds.insetBy(dx: 6, dy: 6))
            imageView.image = NSImage(cgImage: preview, size: imageView.frame.size)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 6
            imageView.layer?.masksToBounds = true
            blur.addSubview(imageView)
        }
        panel.contentView?.addSubview(blur)

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - 180, y: f.minY + 20))
        }

        panel.orderFront(nil)
        self.panel = panel

        let click = NSClickGestureRecognizer(target: self, action: #selector(open))
        blur.addGestureRecognizer(click)
        urlBox = fileURL

        fadeTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    @objc private func open() {
        guard let url = urlBox else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        hide()
    }
}
