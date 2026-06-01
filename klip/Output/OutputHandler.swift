import AppKit
import UserNotifications

final class OutputHandler {
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    func save(gifURL: URL, to folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = "klip-\(formatter.string(from: Date())).gif"
        let destination = folder.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: gifURL, to: destination)
        return destination
    }

    func copyToClipboard(gifURL: URL) throws {
        let data = try Data(contentsOf: gifURL)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
    }

    func sendNotification(filename: String) {
        let content = UNMutableNotificationContent()
        content.title = "GIF saved"
        content.body = "\(filename) — also copied to clipboard"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendError(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func savePNG(image: CGImage, to folder: URL) throws -> URL {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "klip.output", code: -1, userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
        }
        return try savePNGData(data, to: folder)
    }

    func savePNGData(_ data: Data, to folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = "klip-\(formatter.string(from: Date())).png"
        let destination = folder.appendingPathComponent(filename)
        try data.write(to: destination)
        return destination
    }

    func copyPNGToClipboard(image: CGImage) {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        copyPNGDataToClipboard(data)
    }

    func copyPNGDataToClipboard(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }
}
