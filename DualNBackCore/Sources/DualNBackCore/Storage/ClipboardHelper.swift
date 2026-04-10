import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct ClipboardHelper {
    private static let pasteboardType = "io.dualnback.stats"

    public static func copyToClipboard(_ data: Data) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: pasteboardType))
        if let string = String(data: data, encoding: .utf8) {
            item.setString(string, forType: .string)
        }
        pasteboard.writeObjects([item])
        #elseif os(iOS)
        // Write as plain text only. setItems() with an unregistered custom UTI silently fails on iOS,
        // leaving the clipboard unchanged. Universal Clipboard only syncs standard types anyway,
        // and the read path falls back to string regardless.
        if let string = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = string
        }
        #endif
    }

    public static func readFromClipboard() -> Data? {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        let customType = NSPasteboard.PasteboardType(rawValue: pasteboardType)

        // Check each item for our custom type, then plain text
        for item in pasteboard.pasteboardItems ?? [] {
            if let data = item.data(forType: customType) {
                return data
            }
            if let string = item.string(forType: .string) {
                return string.data(using: .utf8)
            }
        }

        // Fallback: pasteboard-level convenience accessors
        if let data = pasteboard.data(forType: customType) {
            return data
        }
        if let string = pasteboard.string(forType: .string) {
            return string.data(using: .utf8)
        }
        return nil
        #elseif os(iOS)
        if let data = UIPasteboard.general.data(forPasteboardType: pasteboardType) {
            return data
        }
        if let string = UIPasteboard.general.string {
            return string.data(using: .utf8)
        }
        return nil
        #else
        return nil
        #endif
    }
}
