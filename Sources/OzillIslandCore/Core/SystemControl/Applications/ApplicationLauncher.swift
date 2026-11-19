import Foundation
import AppKit

/// Kontrak protokol untuk peluncur dan aktivator aplikasi macOS.
@MainActor
public protocol ApplicationLaunching: AnyObject {
    func isApplicationRunning(bundleIdentifier: String) -> Bool
    func launchOrActivate(bundleIdentifier: String) async -> Result<Bool, Error>
    func launchSafari() async -> Result<Bool, Error>
}

/// Error domain untuk peluncuran aplikasi sistem macOS.
public enum ApplicationLauncherError: LocalizedError, Sendable {
    case applicationNotFound(String)
    case launchFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let bundleId):
            return "Aplikasi dengan bundle identifier '\(bundleId)' tidak ditemukan di sistem."
        case .launchFailed(let reason):
            return "Gagal meluncurkan aplikasi: \(reason)"
        }
    }
}

/// Peluncur aplikasi macOS berbasis NSWorkspace & NSRunningApplication (tanpa AppleScript / root).
@MainActor
public final class ApplicationLauncher: ObservableObject, ApplicationLaunching {
    public static let shared = ApplicationLauncher()
    public static let safariBundleId = "com.apple.Safari"
    
    public init() {}
    
    /// Memeriksa apakah aplikasi dengan bundle ID sedang berjalan di sistem
    public func isApplicationRunning(bundleIdentifier: String) -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        return !runningApps.isEmpty
    }
    
    /// Membuka atau mengaktifkan jendela aplikasi tanpa membuat tab baru secara paksa
    public func launchOrActivate(bundleIdentifier: String) async -> Result<Bool, Error> {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        // 1. Jika aplikasi sudah berjalan, aktifkan jendela yang ada
        if let app = runningApps.first {
            let activated = app.activate(options: [.activateIgnoringOtherApps])
            if activated {
                return .success(true)
            }
        }
        
        // 2. Jika belum berjalan, dapatkan URL aplikasi dan luncurkan
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return .failure(ApplicationLauncherError.applicationNotFound(bundleIdentifier))
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = false
        
        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            return .success(true)
        } catch {
            return .failure(ApplicationLauncherError.launchFailed(error.localizedDescription))
        }
    }
    
    /// Membuka atau mengaktifkan browser Safari
    public func launchSafari() async -> Result<Bool, Error> {
        return await launchOrActivate(bundleIdentifier: Self.safariBundleId)
    }
}
