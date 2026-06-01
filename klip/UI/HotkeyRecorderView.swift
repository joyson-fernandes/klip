import SwiftUI
import Carbon.HIToolbox
import AppKit

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var combo: KeyCombo?
    var width: CGFloat = 88

    func makeNSView(context: Context) -> RecorderField {
        let v = RecorderField()
        v.onCombo = { combo = $0 }
        return v
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.combo = combo
        nsView.frame.size.width = width
        nsView.needsDisplay = true
    }
}

final class RecorderField: NSView {
    var combo: KeyCombo? { didSet { needsDisplay = true } }
    var onCombo: ((KeyCombo?) -> Void)?
    private var recording = false
    private var monitor: Any?

    override init(frame: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 88, height: 22))
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 22) }

    override func mouseDown(with event: NSEvent) {
        if recording { stopRecording(); return }
        startRecording()
    }

    private func startRecording() {
        recording = true
        layer?.borderColor = NSColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1).cgColor
        needsDisplay = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            let mods = self.carbonMods(from: event.modifierFlags)
            let captured = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods)
            if captured.hasRequiredModifier {
                self.combo = captured
                self.onCombo?(captured)
            }
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        layer?.borderColor = NSColor.separatorColor.cgColor
        needsDisplay = true
    }

    private func carbonMods(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= KeyCombo.cmd }
        if flags.contains(.shift)   { m |= KeyCombo.shift }
        if flags.contains(.option)  { m |= KeyCombo.option }
        if flags.contains(.control) { m |= KeyCombo.control }
        return m
    }

    override func draw(_ dirtyRect: NSRect) {
        let text = recording ? "Press combo…" : (combo?.displayString ?? "—")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: recording ? NSColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1) : NSColor.labelColor
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}
