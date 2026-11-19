import Foundation

/// Destinasi penyimpanan hasil screenshot.
public enum ScreenshotDestination: String, CaseIterable, Codable, Sendable {
    case desktop
    case customFolder
    case clipboardOnly
}

/// Pengaturan konfigurasi utilitas tangkapan layar Ozill Island.
public struct ScreenshotSettings: Codable, Sendable, Equatable {
    public var destination: ScreenshotDestination
    public var customFolderPath: String?
    public var copyToClipboard: Bool
    public var showNotification: Bool
    
    public init(
        destination: ScreenshotDestination = .desktop,
        customFolderPath: String? = nil,
        copyToClipboard: Bool = true,
        showNotification: Bool = true
    ) {
        self.destination = destination
        self.customFolderPath = customFolderPath
        self.copyToClipboard = copyToClipboard
        self.showNotification = showNotification
    }
    
    public static let `default` = ScreenshotSettings()
}
