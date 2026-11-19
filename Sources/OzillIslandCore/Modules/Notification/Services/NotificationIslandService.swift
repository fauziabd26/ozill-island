import Foundation
import SwiftUI
import AppKit
import ApplicationServices

/// Layanan terpusat pengelola notifikasi yang masuk ke Ozill Island (Jalur A, B, dan C).
@MainActor
public final class NotificationIslandService: ObservableObject {
    public static let shared = NotificationIslandService()
    
    @Published public private(set) var activeNotification: IslandNotification?
    @Published public private(set) var recentNotifications: [IslandNotification] = []
    @Published public private(set) var isAccessibilityAuthorized: Bool = false
    public var isAccessibilityGranted: Bool { isAccessibilityAuthorized }
    
    private var dismissTask: Task<Void, Never>?
    
    public init() {
        checkAccessibilityStatus()
    }
    
    /// Memeriksa status izin Aksesibilitas macOS untuk Jalur A (AXObserver)
    @discardableResult
    public func checkAccessibilityStatus() -> Bool {
        let trusted = AXIsProcessTrusted()
        self.isAccessibilityAuthorized = trusted
        return trusted
    }
    
    /// Membuka prompt sistem atau pengaturan Aksesibilitas
    public func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        self.isAccessibilityAuthorized = trusted
        
        if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    /// Menerbitkan notifikasi baru ke Island (Jalur A, B, atau C)
    public func postNotification(_ notification: IslandNotification) {
        // Simpan ke riwayat (maksimal 30 entri)
        if !recentNotifications.contains(where: { $0.id == notification.id }) {
            recentNotifications.insert(notification, at: 0)
            if recentNotifications.count > 30 {
                recentNotifications.removeLast()
            }
        }
        
        // Batalkan timer dismiss sebelumnya jika ada
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            self.activeNotification = notification
        }
        
        // Bunyi chime halus
        NSSound(named: "Tink")?.play()
        
        // Auto-dismiss setelah durasi selesai
        dismissTask = Task {
            let nanos = UInt64(notification.duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if self.activeNotification?.id == notification.id {
                        self.activeNotification = nil
                    }
                }
            }
        }
    }
    
    /// Menutup notifikasi aktif seketika (saat diklik atau di-swipe)
    public func dismissActiveNotification() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            self.activeNotification = nil
        }
    }
    
    /// Simulasi notifikasi untuk pengujian visual langsung
    public func simulateNotification(type: String) {
        let notif: IslandNotification
        switch type.lowercased() {
        case "whatsapp":
            notif = IslandNotification(
                appName: "WhatsApp",
                title: "Rina Salsabila",
                message: "Halo cuy! Tugas desainnya udah siap dikirim?",
                iconSymbol: "message.fill",
                accentHex: "#25D366" // WhatsApp Green
            )
        case "instagram":
            notif = IslandNotification(
                appName: "Instagram",
                title: "alex_creative",
                message: "Menyukai cerita Anda dan mengirim pesan",
                iconSymbol: "camera.fill",
                accentHex: "#E1306C" // Instagram Pink/Magenta
            )
        case "telegram":
            notif = IslandNotification(
                appName: "Telegram",
                title: "Komunitas Swift Developer",
                message: "Xcode 16.2 Release Candidate resmi dirilis hari ini!",
                iconSymbol: "paperplane.fill",
                accentHex: "#2AABEE" // Telegram Blue
            )
        default:
            notif = IslandNotification(
                appName: "Pesan Sistem",
                title: "Pengingat Otomatis",
                message: "Ozill Island siap menyambut notifikasi barumu.",
                iconSymbol: "bell.fill",
                accentHex: "#00D2FF"
            )
        }
        postNotification(notif)
    }
}
