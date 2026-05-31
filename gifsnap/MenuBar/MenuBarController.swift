import AppKit
import Carbon
import SwiftUI
import ScreenCaptureKit

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let settings = SettingsStore()
    private let captureEngine = CaptureEngine()
    private let gifEncoder = GIFEncoder()
    private let outputHandler = OutputHandler()
    private let regionSelector = RegionSelector()
    private let hud = RecordingHUD()
    private var isRecording = false
    private var hotKeyRef: EventHotKeyRef?
    private var observableSettings: SettingsStoreObservable!

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        setupHotKey()
        regionSelector.delegate = self
        captureEngine.delegate = self
        outputHandler.requestNotificationPermission()
        requestScreenRecordingPermission()
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "gifsnap")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        observableSettings = SettingsStoreObservable(store: settings)
        observableSettings.load()
        let view = PopoverView(
            settings: observableSettings,
            onStartCapture: { [weak self] in self?.startCaptureFlow() },
            onSelectFolder: { [weak self] in self?.selectSaveFolder() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: view)
        popover.behavior = .transient
        popover.animates = false
    }

    private func setupHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData = userData else { return noErr }
            let controller = Unmanaged<MenuBarController>.fromOpaque(userData).takeUnretainedValue()
            controller.handleHotKey()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x67736e70), id: 1)
        let gKeyCode: UInt32 = 5
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(gKeyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func requestScreenRecordingPermission() {
        Task { _ = try? await SCShareableContent.current }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            observableSettings.load()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func handleHotKey() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isRecording {
                self.stopRecording()
            } else {
                self.startCaptureFlow()
            }
        }
    }

    private func selectSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            observableSettings.saveFolder = url
        }
    }

    private func startCaptureFlow() {
        popover.performClose(nil)
        regionSelector.show()
    }

    private func stopRecording() {
        hud.hide()
        isRecording = false
        Task { await captureEngine.stop() }
    }
}

extension MenuBarController: RegionSelectorDelegate {
    func regionSelector(_ selector: RegionSelector, didSelect rect: CGRect, on screen: NSScreen) {
        isRecording = true
        hud.show(near: rect)
        Task {
            do {
                try await captureEngine.start(rect: rect, screen: screen, fps: settings.fps)
            } catch {
                await MainActor.run {
                    self.hud.hide()
                    self.isRecording = false
                }
            }
        }
    }

    func regionSelectorDidCancel(_ selector: RegionSelector) {}
}

extension MenuBarController: CaptureEngineDelegate {
    func captureEngineDidFinish(_ engine: CaptureEngine, framesDirectory: URL) {
        Task {
            do {
                let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
                let outputURL = outputDir.appendingPathComponent("output.gif")

                try gifEncoder.encode(
                    framesDirectory: framesDirectory,
                    outputURL: outputURL,
                    fps: settings.fps,
                    maxWidth: settings.maxWidth,
                    loopCount: settings.loopCount
                )

                let savedURL = try outputHandler.save(gifURL: outputURL, to: settings.saveFolder)
                try outputHandler.copyToClipboard(gifURL: savedURL)
                outputHandler.sendNotification(filename: savedURL.lastPathComponent)

                try? FileManager.default.removeItem(at: framesDirectory)
                try? FileManager.default.removeItem(at: outputDir)
            } catch {
                print("gifsnap error: \(error)")
            }
        }
    }

    func captureEngineDidFail(_ engine: CaptureEngine, error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.hud.hide()
            self?.isRecording = false
        }
    }
}
