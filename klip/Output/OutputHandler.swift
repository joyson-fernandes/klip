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
        // Writing both NSImage and raw PNG/TIFF data so any app accepting image paste works.
        // Just setData(.png) alone misses some apps that expect .tiff or an NSImage class.
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        let rep = NSBitmapImageRep(cgImage: image)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }
        if let tiffData = rep.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    func copyPNGDataToClipboard(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let nsImage = NSImage(data: data) {
            pasteboard.writeObjects([nsImage])
        }
        pasteboard.setData(data, forType: .png)
        if let rep = NSBitmapImageRep(data: data), let tiff = rep.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }
}
