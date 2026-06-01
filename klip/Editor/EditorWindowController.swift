import AppKit
import SwiftUI

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let state: EditorState
    private let onSave: (Data) -> Void
    private let onCancel: () -> Void
    private var toolbarPanel: NSPanel?

    init(image: CGImage, onSave: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.state = EditorState(image: image)
        self.onSave = onSave
        self.onCancel = onCancel

        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        let canvas = AnnotationCanvas(state: state)
        scrollView.documentView = canvas

        let logicalSize = NSSize(
            width: CGFloat(image.width) / (NSScreen.main?.backingScaleFactor ?? 2),
            height: CGFloat(image.height) / (NSScreen.main?.backingScaleFactor ?? 2)
        )
        let windowFrame = NSRect(
            x: 100, y: 100,
            width: min(1200, max(640, logicalSize.width + 80)),
            height: min(800, max(420, logicalSize.height + 120))
        )

        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "klip — \(image.width) × \(image.height)"
        window.titlebarAppearsTransparent = true
        window.contentView = scrollView
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self

        let bar = NSTitlebarAccessoryViewController()
        bar.layoutAttribute = .right
        let host = NSHostingView(rootView: TitlebarButtons(onCancel: { [weak self] in self?.cancel() },
                                                            onSave: { [weak self] in self?.save() }))
        host.frame = NSRect(x: 0, y: 0, width: 160, height: 28)
        bar.view = host
        window.addTitlebarAccessoryViewController(bar)

        DispatchQueue.main.async {
            self.presentFloatingToolbar(parent: window)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func presentFloatingToolbar(parent: NSWindow) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating

        let host = NSHostingView(rootView: ToolbarView(state: state, onSave: { [weak self] in self?.save() }, onCancel: { [weak self] in self?.cancel() }))
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(host)
        toolbarPanel = panel

        repositionToolbar(parent: parent)
        panel.orderFront(nil)
        parent.addChildWindow(panel, ordered: .above)
    }

    private func repositionToolbar(parent: NSWindow) {
        guard let panel = toolbarPanel else { return }
        let parentFrame = parent.frame
        let x = parentFrame.midX - panel.frame.width / 2
        let y = parentFrame.minY + 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidResize(_ notification: Notification) {
        if let w = notification.object as? NSWindow { repositionToolbar(parent: w) }
    }

    func windowDidMove(_ notification: Notification) {
        if let w = notification.object as? NSWindow { repositionToolbar(parent: w) }
    }

    func save() {
        guard let data = AnnotationRenderer.flatten(image: state.image, annotations: state.annotations) else {
            cancel(); return
        }
        onSave(data)
        close()
    }

    func cancel() {
        onCancel()
        close()
    }
}

private struct TitlebarButtons: View {
    let onCancel: () -> Void
    let onSave: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
            Button("Save", action: onSave)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.37, green: 0.36, blue: 0.90))
        }
        .padding(.horizontal, 10)
    }
}
