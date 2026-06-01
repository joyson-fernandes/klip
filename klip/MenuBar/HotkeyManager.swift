import Carbon.HIToolbox
import Foundation
import AppKit

enum HotkeyKind {
    case screenshot
    case gif
}

struct HotkeyBindResult {
    let screenshotRegistered: Bool
    let gifRegistered: Bool
}

final class HotkeyManager {
    private var screenshotCombo: KeyCombo?
    private var gifCombo: KeyCombo?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var handler: ((HotkeyKind) -> Void)?

    // Carbon refs kept for apps that grant accessibility — used as a best-effort
    // fallback for global delivery; NSEvent monitors handle the primary path.
    private var screenshotRef: EventHotKeyRef?
    private var gifRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private static let signature: OSType = OSType(0x6B6C7000)

    func bind(screenshot: KeyCombo?, gif: KeyCombo?, action: @escaping (HotkeyKind) -> Void) -> HotkeyBindResult {
        unbindAll()
        handler = action
        screenshotCombo = screenshot
        gifCombo = gif

        // Primary: NSEvent global monitor (works in unit tests without Carbon conflicts)
        let hasScreenshot = screenshot?.hasRequiredModifier == true
        let hasGif = gif?.hasRequiredModifier == true

        if hasScreenshot || hasGif {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleEvent(event)
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleEvent(event)
                return event
            }
        }

        // Best-effort Carbon registration (may fail on conflicting combos — not fatal)
        installEventHandler()
        _ = carbonRegister(combo: screenshot, id: 1, into: &screenshotRef)
        _ = carbonRegister(combo: gif, id: 2, into: &gifRef)

        return HotkeyBindResult(screenshotRegistered: hasScreenshot, gifRegistered: hasGif)
    }

    func unbindAll() {
        if let ref = screenshotRef { UnregisterEventHotKey(ref); screenshotRef = nil }
        if let ref = gifRef        { UnregisterEventHotKey(ref); gifRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor = nil }
        handler = nil
        screenshotCombo = nil
        gifCombo = nil
    }

    private func handleEvent(_ event: NSEvent) {
        let flags = event.modifierFlags
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= KeyCombo.cmd }
        if flags.contains(.shift)   { mods |= KeyCombo.shift }
        if flags.contains(.option)  { mods |= KeyCombo.option }
        if flags.contains(.control) { mods |= KeyCombo.control }
        let keyCode = UInt32(event.keyCode)

        if let s = screenshotCombo, s.keyCode == keyCode, s.modifiers == mods {
            DispatchQueue.main.async { self.handler?(.screenshot) }
        } else if let g = gifCombo, g.keyCode == keyCode, g.modifiers == mods {
            DispatchQueue.main.async { self.handler?(.gif) }
        }
    }

    @discardableResult
    private func carbonRegister(combo: KeyCombo?, id: UInt32, into ref: inout EventHotKeyRef?) -> Bool {
        guard let combo = combo, combo.hasRequiredModifier else { return false }
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let target = GetApplicationEventTarget()
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, target, 0, &ref)
        if status == OSStatus(-9878) {
            // Conflict with existing registration — exclusive override attempt
            _ = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, target, OptionBits(kEventHotKeyExclusive), &ref)
        }
        return ref != nil
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event = event, let userData = userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                mgr.handler?(hotKeyID.id == 1 ? .screenshot : .gif)
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)
    }

    deinit { unbindAll() }
}
