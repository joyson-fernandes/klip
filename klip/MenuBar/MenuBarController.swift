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
    private let hotkeyManager = HotkeyManager()
    private var pendingCaptureKind: HotkeyKind = .gif
    private var observableSettings: SettingsStoreObservable!
    private var clickOutsideMonitor: Any?

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        bindHotkeys()
        regionSelector.delegate = self
        captureEngine.delegate = self
        outputHandler.requestNotificationPermission()
        requestScreenRecordingPermission()
        try? FileManager.default.createDirectory(at: settings.saveFolder, withIntermediateDirectories: true)
    }

    deinit {
        hotkeyManager.unbindAll()
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "klip")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        observableSettings = SettingsStoreObservable(store: settings)
        observableSettings.load()
        observableSettings.onHotkeyChanged = { [weak self] in
            self?.rebindHotkeysAfterSettingsChange()
        }
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

    private func bindHotkeys() {
        let result = hotkeyManager.bind(
            screenshot: settings.screenshotHotkey,
            gif: settings.gifHotkey
        ) { [weak self] kind in
            self?.handleHotkey(kind: kind)
        }
        if !result.screenshotRegistered && settings.screenshotHotkey != nil {
            outputHandler.sendError(title: "Screenshot hotkey unavailable", body: "Could not register the configured combo (likely taken by another app).")
        }
        if !result.gifRegistered && settings.gifHotkey != nil {
            outputHandler.sendError(title: "GIF hotkey unavailable", body: "Could not register the configured combo (likely taken by another app).")
        }
    }

    func rebindHotkeysAfterSettingsChange() {
        bindHotkeys()
    }

    private func requestScreenRecordingPermission() {
        Task { _ = try? await SCShareableContent.current }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            observableSettings.load()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Dismiss when clicking anywhere outside (LSUIElement apps don't get .transient
            // dismissal for free because the app isn't activated on icon click).
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        popover.performClose(nil)
    }

    func handleHotkey(kind: HotkeyKind) {
        if isRecording {
            stopRecording()
            return
        }
        pendingCaptureKind = kind
        startCaptureFlow()
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
        switch pendingCaptureKind {
        case .gif:
            isRecording = true
            hud.show(near: rect)
            Task {
                do {
                    try await captureEngine.start(rect: rect, screen: screen, fps: settings.fps)
                } catch {
                    NSLog("klip: capture start failed: %@", String(describing: error))
                    await MainActor.run {
                        self.hud.hide()
                        self.isRecording = false
                        self.outputHandler.sendError(
                            title: "Capture failed",
                            body: "Grant Screen Recording permission in System Settings, then quit and reopen klip."
                        )
                    }
                }
            }
        case .screenshot:
            guard let image = ScreenshotCapture.capture(rect: rect, screen: screen) else {
                outputHandler.sendError(title: "Screenshot failed", body: "Could not capture the selected region.")
                return
            }
            do {
                let savedURL = try outputHandler.savePNG(image: image, to: settings.saveFolder)
                outputHandler.copyPNGToClipboard(image: image)
                outputHandler.sendNotification(filename: savedURL.lastPathComponent)
            } catch {
                outputHandler.sendError(title: "Couldn't save screenshot", body: String(describing: error))
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
                NSLog("klip: encode/save failed: %@", String(describing: error))
                await MainActor.run {
                    self.outputHandler.sendError(
                        title: "Couldn't save GIF",
                        body: String(describing: error)
                    )
                }
            }
        }
    }

    func captureEngineDidFail(_ engine: CaptureEngine, error: Error) {
        NSLog("klip: capture stream failed: %@", String(describing: error))
        DispatchQueue.main.async { [weak self] in
            self?.hud.hide()
            self?.isRecording = false
            self?.outputHandler.sendError(
                title: "Recording stopped",
                body: String(describing: error)
            )
        }
    }
}
