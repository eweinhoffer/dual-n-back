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
        pasteboard.setData(data, forType: .init(pasteboardType))
        if let string = String(data: data, encoding: .utf8) {
            pasteboard.setString(string, forType: .string)
        }
        #elseif os(iOS)
        UIPasteboard.general.setData(data, forPasteboardType: pasteboardType)
        if let string = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = string
        }
        #endif
    }

    public static func readFromClipboard() -> Data? {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .init(pasteboardType)) {
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
