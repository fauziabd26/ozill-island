import Foundation
import ServiceManagement
import SwiftUI

/// Pengelola startup otomatis saat Mac dinyalakan menggunakan API modern ServiceManagement (macOS 13+).
@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public private(set) var isEnabled: Bool = false
    
    public init() {
        refreshStatus()
    }
    
    /// Memperbarui status pendaftaran ServiceManagement
    public func refreshStatus() {
        if #available(macOS 13.0, *) {
            self.isEnabled = (SMAppService.mainApp.status == .enabled)
        } else {
            self.isEnabled = false
        }
    }
    
    /// Mengatur apakah aplikasi berjalan otomatis saat login
    public func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                refreshStatus()
            } catch {
                print("LaunchAtLoginManager: Gagal mengubah status login - \(error)")
                refreshStatus()
            }
        }
    }
}
