import Foundation

final class SettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let fps = "fps"
        static let maxWidth = "maxWidth"
        static let loopCount = "loopCount"
        static let saveFolder = "saveFolder"
        static let screenshotHotkey = "screenshotHotkey"
        static let gifHotkey = "gifHotkey"
    }

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    var fps: Int {
        get {
            let v = defaults.integer(forKey: Key.fps)
            return v == 0 ? 10 : min(30, max(5, v))
        }
        set { defaults.set(min(30, max(5, newValue)), forKey: Key.fps) }
    }

    var maxWidth: Int {
        get {
            let v = defaults.integer(forKey: Key.maxWidth)
            return v == 0 ? 1200 : min(2400, max(400, v))
        }
        set { defaults.set(min(2400, max(400, newValue)), forKey: Key.maxWidth) }
    }

    var loopCount: Int {
        get { defaults.object(forKey: Key.loopCount) == nil ? 0 : defaults.integer(forKey: Key.loopCount) }
        set { defaults.set(max(0, newValue), forKey: Key.loopCount) }
    }

    var saveFolder: URL {
        get {
            if let data = defaults.data(forKey: Key.saveFolder) {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    return url
                }
            }
            return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Screenshots")
        }
        set {
            let data = try? newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: Key.saveFolder)
        }
    }

    var screenshotHotkey: KeyCombo? {
        get { decodeCombo(forKey: Key.screenshotHotkey, default: KeyCombo.defaultScreenshot) }
        set { encodeCombo(newValue, forKey: Key.screenshotHotkey) }
    }

    var gifHotkey: KeyCombo? {
        get { decodeCombo(forKey: Key.gifHotkey, default: KeyCombo.defaultGif) }
        set { encodeCombo(newValue, forKey: Key.gifHotkey) }
    }

    private func decodeCombo(forKey key: String, default fallback: KeyCombo) -> KeyCombo? {
        if defaults.bool(forKey: key + ".cleared") { return nil }
        guard let data = defaults.data(forKey: key) else { return fallback }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    private func encodeCombo(_ combo: KeyCombo?, forKey key: String) {
        if let combo = combo {
            defaults.set(false, forKey: key + ".cleared")
            defaults.set(try? JSONEncoder().encode(combo), forKey: key)
        } else {
            defaults.set(true, forKey: key + ".cleared")
            defaults.removeObject(forKey: key)
        }
    }
}
