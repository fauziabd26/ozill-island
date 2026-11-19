import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit
import UserNotifications

/// Informasi jendela aplikasi yang dapat ditangkap oleh Screenshot Utility.
public struct CaptureableWindowInfo: Identifiable, Sendable, Equatable {
    public let id: CGWindowID
    public let title: String
    public let appName: String
    public let appBundleId: String?
    public let frame: CGRect
    
    public init(id: CGWindowID, title: String, appName: String, appBundleId: String?, frame: CGRect) {
        self.id = id
        self.title = title
        self.appName = appName
        self.appBundleId = appBundleId
        self.frame = frame
    }
}

/// Kesalahan operasi tangkapan layar.
public enum ScreenshotError: LocalizedError, Sendable, Equatable {
    case permissionDenied
    case userCancelled
    case displayNotFound
    case windowNotFound
    case captureFailed(String)
    case encodingFailed
    case fileWriteFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Izin Perekaman Layar (Screen Recording) belum diberikan. Silakan aktifkan di System Settings > Privacy & Security > Screen & System Audio Recording."
        case .userCancelled:
            return "Penangkapan layar dibatalkan oleh pengguna."
        case .displayNotFound:
            return "Layar tampilan untuk tangkapan layar tidak ditemukan."
        case .windowNotFound:
            return "Jendela aplikasi yang dipilih tidak valid atau sudah ditutup."
        case .captureFailed(let reason):
            return "Gagal menangkap layar: \(reason)"
        case .encodingFailed:
            return "Gagal mengonversi gambar hasil tangkapan ke format PNG."
        case .fileWriteFailed(let reason):
            return "Gagal menyimpan berkas tangkapan layar: \(reason)"
        }
    }
}

/// Kontrak abstraksi hardware untuk operasi pengambilan tangkapan layar.
public protocol ScreenshotHardwareBridging: Sendable {
    func checkPermission() -> Bool
    func captureFullScreen(displayId: CGDirectDisplayID) async -> Result<CGImage, Error>
    func captureArea(_ rect: CGRect, displayId: CGDirectDisplayID) async -> Result<CGImage, Error>
    func captureWindow(windowId: CGWindowID) async -> Result<CGImage, Error>
    func getCaptureableWindows() async -> [CaptureableWindowInfo]
}

/// Implementasi native ScreenCaptureKit resmi macOS (tanpa private API).
public final class NativeScreenshotHardwareBridge: ScreenshotHardwareBridging, @unchecked Sendable {
    public init() {}
    
    public func checkPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    public func captureFullScreen(displayId: CGDirectDisplayID) async -> Result<CGImage, Error> {
        guard checkPermission() else {
            return .failure(ScreenshotError.permissionDenied)
        }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayId }) ?? content.displays.first else {
                return .failure(ScreenshotError.displayNotFound)
            }
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false
            
            if #available(macOS 14.0, *) {
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                return .success(image)
            } else {
                return .failure(ScreenshotError.captureFailed("SCScreenshotManager memerlukan macOS 14.0 atau lebih baru"))
            }
        } catch {
            return .failure(ScreenshotError.captureFailed(error.localizedDescription))
        }
    }
    
    public func captureArea(_ rect: CGRect, displayId: CGDirectDisplayID) async -> Result<CGImage, Error> {
        guard checkPermission() else {
            return .failure(ScreenshotError.permissionDenied)
        }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayId }) ?? content.displays.first else {
                return .failure(ScreenshotError.displayNotFound)
            }
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            
            // Konversi koordinat fisik layar dan batasan sourceRect
            let clampedRect = rect.intersection(CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height)))
            guard clampedRect.width > 1 && clampedRect.height > 1 else {
                return .failure(ScreenshotError.captureFailed("Area seleksi terlalu kecil atau di luar batas layar"))
            }
            
            config.sourceRect = clampedRect
            config.width = Int(clampedRect.width)
            config.height = Int(clampedRect.height)
            config.showsCursor = false
            config.scalesToFit = true
            
            if #available(macOS 14.0, *) {
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                return .success(image)
            } else {
                return .failure(ScreenshotError.captureFailed("SCScreenshotManager memerlukan macOS 14.0 atau lebih baru"))
            }
        } catch {
            return .failure(ScreenshotError.captureFailed(error.localizedDescription))
        }
    }
    
    public func captureWindow(windowId: CGWindowID) async -> Result<CGImage, Error> {
        guard checkPermission() else {
            return .failure(ScreenshotError.permissionDenied)
        }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowId }) else {
                return .failure(ScreenshotError.windowNotFound)
            }
            
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(scWindow.frame.width)
            config.height = Int(scWindow.frame.height)
            config.showsCursor = false
            
            if #available(macOS 14.0, *) {
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                return .success(image)
            } else {
                return .failure(ScreenshotError.captureFailed("SCScreenshotManager memerlukan macOS 14.0 atau lebih baru"))
            }
        } catch {
            return .failure(ScreenshotError.captureFailed(error.localizedDescription))
        }
    }
    
    public func getCaptureableWindows() async -> [CaptureableWindowInfo] {
        guard checkPermission() else { return [] }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return content.windows.compactMap { w in
                guard w.frame.width > 50 && w.frame.height > 50 else { return nil }
                let title = w.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let appName = w.owningApplication?.applicationName ?? "Aplikasi"
                let bundleId = w.owningApplication?.bundleIdentifier
                return CaptureableWindowInfo(
                    id: w.windowID,
                    title: title.isEmpty ? appName : title,
                    appName: appName,
                    appBundleId: bundleId,
                    frame: w.frame
                )
            }
        } catch {
            return []
        }
    }
}

/// Kontrak protokol pengontrol screenshot.
@MainActor
public protocol ScreenshotControlling: AnyObject {
    var isCapturing: Bool { get }
    var lastResult: ScreenshotResult? { get }
    var selectedMode: ScreenshotMode? { get set }
    var settings: ScreenshotSettings { get set }
    var availableWindows: [CaptureableWindowInfo] { get }
    
    func checkPermission() -> Bool
    func openPermissionSettings()
    func executeCapture(mode: ScreenshotMode, displayId: CGDirectDisplayID?, windowId: CGWindowID?, rect: CGRect?) async -> Result<ScreenshotResult, Error>
    func refreshCaptureableWindows() async
}

/// Pengontrol utilitas tangkapan layar Ozill Island yang modular, privacy-first,
/// dan mendukung Full Screen, Area Selektif, dan Window Capture.
@MainActor
public final class ScreenshotController: ObservableObject, ScreenshotControlling {
    public static let shared = ScreenshotController()
    
    @Published public private(set) var isCapturing: Bool = false
    @Published public private(set) var lastResult: ScreenshotResult?
    @Published public var selectedMode: ScreenshotMode?
    @Published public var settings: ScreenshotSettings = .default
    @Published public private(set) var availableWindows: [CaptureableWindowInfo] = []
    
    private let hardwareBridge: any ScreenshotHardwareBridging
    
    public init(hardwareBridge: any ScreenshotHardwareBridging = NativeScreenshotHardwareBridge()) {
        self.hardwareBridge = hardwareBridge
    }
    
    public func checkPermission() -> Bool {
        return hardwareBridge.checkPermission()
    }
    
    public func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func refreshCaptureableWindows() async {
        self.availableWindows = await hardwareBridge.getCaptureableWindows()
    }
    
    /// Mengeksekusi penangkapan layar sesuai mode yang dipilih
    public func executeCapture(
        mode: ScreenshotMode,
        displayId: CGDirectDisplayID? = nil,
        windowId: CGWindowID? = nil,
        rect: CGRect? = nil
    ) async -> Result<ScreenshotResult, Error> {
        guard checkPermission() else {
            return .failure(ScreenshotError.permissionDenied)
        }
        
        self.isCapturing = true
        defer { self.isCapturing = false }
        
        let targetDisplay = displayId ?? CGMainDisplayID()
        let captureResult: Result<CGImage, Error>
        
        switch mode {
        case .fullScreen:
            captureResult = await hardwareBridge.captureFullScreen(displayId: targetDisplay)
        case .selectedArea:
            guard let validRect = rect, validRect.width > 1 && validRect.height > 1 else {
                return .failure(ScreenshotError.userCancelled)
            }
            captureResult = await hardwareBridge.captureArea(validRect, displayId: targetDisplay)
        case .window:
            guard let targetWindow = windowId else {
                return .failure(ScreenshotError.windowNotFound)
            }
            captureResult = await hardwareBridge.captureWindow(windowId: targetWindow)
        }
        
        switch captureResult {
        case .failure(let err):
            return .failure(err)
        case .success(let cgImage):
            let rep = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = rep.representation(using: .png, properties: [:]) else {
                return .failure(ScreenshotError.encodingFailed)
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            var savedURL: URL? = nil
            var copiedToClipboard = false
            
            // 1. Output Clipboard
            if settings.copyToClipboard || settings.destination == .clipboardOnly {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([nsImage])
                NSPasteboard.general.setData(pngData, forType: .png)
                copiedToClipboard = true
            }
            
            // 2. Output File System (Desktop / Custom)
            if settings.destination != .clipboardOnly {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let timestampStr = formatter.string(from: Date())
                let fileName = "Ozill_Screenshot_\(timestampStr).png"
                
                let targetDirURL: URL
                if settings.destination == .customFolder, let path = settings.customFolderPath, !path.isEmpty {
                    targetDirURL = URL(fileURLWithPath: path)
                } else {
                    targetDirURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
                }
                
                let fileURL = targetDirURL.appendingPathComponent(fileName)
                do {
                    try pngData.write(to: fileURL, options: .atomic)
                    savedURL = fileURL
                } catch {
                    return .failure(ScreenshotError.fileWriteFailed(error.localizedDescription))
                }
            }
            
            let result = ScreenshotResult(
                image: nsImage,
                pngData: pngData,
                mode: mode,
                savedURL: savedURL,
                copiedToClipboard: copiedToClipboard,
                pixelWidth: cgImage.width,
                pixelHeight: cgImage.height
            )
            
            self.lastResult = result
            
            // 3. Tampilkan Notifikasi Sistem jika diaktifkan
            if settings.showNotification {
                sendSuccessNotification(result: result)
            }
            
            return .success(result)
        }
    }
    
    private func sendSuccessNotification(result: ScreenshotResult) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tangkapan Layar Berhasil (\(result.mode.title))"
        if let url = result.savedURL {
            content.body = "Tersimpan di \(url.lastPathComponent)"
        } else if result.copiedToClipboard {
            content.body = "Tersalin ke Clipboard"
        }
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: "ozill-screenshot-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
