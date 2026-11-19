import Foundation
import AppKit

/// Hasil penangkapan layar tangkapan yang memuat metadata, representasi gambar, dan status penyimpanan.
public struct ScreenshotResult: Sendable {
    public let image: NSImage
    public let pngData: Data
    public let mode: ScreenshotMode
    public let savedURL: URL?
    public let copiedToClipboard: Bool
    public let timestamp: Date
    public let pixelWidth: Int
    public let pixelHeight: Int
    
    public init(
        image: NSImage,
        pngData: Data,
        mode: ScreenshotMode,
        savedURL: URL?,
        copiedToClipboard: Bool,
        timestamp: Date = Date(),
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.image = image
        self.pngData = pngData
        self.mode = mode
        self.savedURL = savedURL
        self.copiedToClipboard = copiedToClipboard
        self.timestamp = timestamp
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}
