import SwiftUI

struct PopoverView: View {
    @ObservedObject var settings: SettingsStoreObservable
    let onStartCapture: () -> Void
    let onSelectFolder: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.37, green: 0.36, blue: 0.90))
                    .frame(width: 32, height: 32)
                    .overlay(Text("🎞").font(.system(size: 18)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("gifsnap").font(.headline)
                    Text("⌘⇧G to capture").font(.caption).foregroundColor(.secondary)
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
                ), in: 400...1600, step: 50)

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

            HStack {
                Button("Quit", action: onQuit)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
                Text("v1.0.0").font(.caption).foregroundColor(.secondary)
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

    var saveFolderName: String { store.saveFolder.lastPathComponent }
    var saveFolder: URL {
        get { store.saveFolder }
        set { store.saveFolder = newValue; objectWillChange.send() }
    }

    func load() {
        fps = store.fps
        maxWidth = store.maxWidth
        loopCount = store.loopCount
    }
}
