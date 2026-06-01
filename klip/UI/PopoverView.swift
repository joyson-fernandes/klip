import SwiftUI

struct PopoverView: View {
    @ObservedObject var settings: SettingsStoreObservable
    let onStartCapture: () -> Void
    let onSelectFolder: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("klip").font(.headline)
                    Text(
                        "\(settings.screenshotHotkey?.displayString ?? "—") screenshot   ·   "
                        + "\(settings.gifHotkey?.displayString ?? "—") GIF"
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .padding()

            Button(action: onStartCapture) {
                Text("▶  Start Capture")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.37, green: 0.36, blue: 0.90))
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("SETTINGS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)

                HStack {
                    Text("Frame rate").font(.callout)
                    Spacer()
                    Text("\(settings.fps) fps").font(.callout).foregroundColor(.accentColor)
                }
                Slider(value: Binding(
                    get: { Double(settings.fps) },
                    set: { settings.fps = Int($0) }
                ), in: 5...30, step: 1)

                HStack {
                    Text("Max width").font(.callout)
                    Spacer()
                    Text("\(settings.maxWidth) px").font(.callout).foregroundColor(.accentColor)
                }
                Slider(value: Binding(
                    get: { Double(settings.maxWidth) },
                    set: { settings.maxWidth = Int($0) }
                ), in: 400...2400, step: 50)

                HStack {
                    Text("Loop").font(.callout)
                    Spacer()
                    Picker("", selection: $settings.loopCount) {
                        Text("∞ forever").tag(0)
                        Text("1×").tag(1)
                        Text("2×").tag(2)
                        Text("3×").tag(3)
                        Text("5×").tag(5)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 90)
                }

                HStack {
                    Text("Save to").font(.callout)
                    Spacer()
                    Button(action: onSelectFolder) {
                        Text(settings.saveFolderName)
                            .font(.callout)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Divider().padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                Text("HOTKEYS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                HStack {
                    Text("Screenshot").font(.callout)
                    Spacer()
                    HotkeyRecorderView(combo: $settings.screenshotHotkey)
                        .frame(width: 88, height: 22)
                    Button(action: { settings.screenshotHotkey = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Text("Record GIF").font(.callout)
                    Spacer()
                    HotkeyRecorderView(combo: $settings.gifHotkey)
                        .frame(width: 88, height: 22)
                    Button(action: { settings.gifHotkey = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button("Reset to defaults") {
                    settings.screenshotHotkey = KeyCombo.defaultScreenshot
                    settings.gifHotkey = KeyCombo.defaultGif
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.caption)
                .padding(.top, 2)
            }
            .padding(.horizontal)

            Divider().padding(.top, 12)

            HStack {
                Button("Quit", action: onQuit)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
                Text("v1.1.0").font(.caption).foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 240)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

final class SettingsStoreObservable: ObservableObject {
    private let store: SettingsStore

    init(store: SettingsStore) { self.store = store }

    @Published var fps: Int = 10 { didSet { store.fps = fps } }
    @Published var maxWidth: Int = 800 { didSet { store.maxWidth = maxWidth } }
    @Published var loopCount: Int = 0 { didSet { store.loopCount = loopCount } }
    @Published var screenshotHotkey: KeyCombo? = KeyCombo.defaultScreenshot {
        didSet { store.screenshotHotkey = screenshotHotkey; onHotkeyChanged?() }
    }
    @Published var gifHotkey: KeyCombo? = KeyCombo.defaultGif {
        didSet { store.gifHotkey = gifHotkey; onHotkeyChanged?() }
    }
    var onHotkeyChanged: (() -> Void)?

    var saveFolderName: String { store.saveFolder.lastPathComponent }
    var saveFolder: URL {
        get { store.saveFolder }
        set { store.saveFolder = newValue; objectWillChange.send() }
    }

    func load() {
        fps = store.fps
        maxWidth = store.maxWidth
        loopCount = store.loopCount
        screenshotHotkey = store.screenshotHotkey
        gifHotkey = store.gifHotkey
    }
}
