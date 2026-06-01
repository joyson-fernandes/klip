import Carbon.HIToolbox
import Foundation

enum HotkeyKind {
    case screenshot
    case gif
}

struct HotkeyBindResult {
    let screenshotRegistered: Bool
    let gifRegistered: Bool
}

final class HotkeyManager {
    private var screenshotRef: EventHotKeyRef?
    private var gifRef: EventHotKeyRef?
    private var handler: ((HotkeyKind) -> Void)?
    private var eventHandlerInstalled = false
    private static let signature: OSType = OSType(0x6B6C7000)

    func bind(screenshot: KeyCombo?, gif: KeyCombo?, action: @escaping (HotkeyKind) -> Void) -> HotkeyBindResult {
        unbindAll()
        handler = action
        installEventHandlerIfNeeded()
        let s = register(combo: screenshot, id: 1, into: &screenshotRef)
        let g = register(combo: gif, id: 2, into: &gifRef)
        return HotkeyBindResult(screenshotRegistered: s, gifRegistered: g)
    }

    func unbindAll() {
        if let ref = screenshotRef { UnregisterEventHotKey(ref); screenshotRef = nil }
        if let ref = gifRef        { UnregisterEventHotKey(ref); gifRef = nil }
        handler = nil
    }

    private func register(combo: KeyCombo?, id: UInt32, into ref: inout EventHotKeyRef?) -> Bool {
        guard let combo = combo, combo.hasRequiredModifier else { return false }
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        return status == noErr
    }

    private func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true
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
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    deinit { unbindAll() }
}
