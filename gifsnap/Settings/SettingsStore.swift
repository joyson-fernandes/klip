import Foundation

final class SettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let fps = "fps"
        static let maxWidth = "maxWidth"
        static let loopCount = "loopCount"
        static let saveFolder = "saveFolder"
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
            return v == 0 ? 800 : min(1600, max(400, v))
        }
        set { defaults.set(min(1600, max(400, newValue)), forKey: Key.maxWidth) }
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
}
