import Foundation
import SwiftUI
import AppKit
import ApplicationServices

/// Layanan terpusat pengelola notifikasi yang masuk ke Ozill Island (Jalur A, B, dan C) dengan physics animasi fluid.
@MainActor
public final class NotificationIslandService: ObservableObject {
    public static let shared = NotificationIslandService()
    
    @Published public private(set) var activeNotification: IslandNotification?
    @Published public private(set) var recentNotifications: [IslandNotification] = []
    @Published public private(set) var isAccessibilityAuthorized: Bool = false
    public var isAccessibilityGranted: Bool { isAccessibilityAuthorized }
    
    /// Menyimpan sisa waktu durasi untuk interaksi hover pause
    @Published public private(set) var isHoverPaused: Bool = false
    private var dismissTask: Task<Void, Never>?
    private var notificationStartTime: Date?
    private var remainingDuration: TimeInterval = 5.0
    
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
    
    /// Menerbitkan notifikasi baru ke Island (Jalur A, B, atau C) dengan animasi spring fluid
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
        isHoverPaused = false
        remainingDuration = notification.duration
        notificationStartTime = Date()
        
        // Fluid spring curve ala Apple Dynamic Island
        withAnimation(.spring(response: 0.44, dampingFraction: 0.76)) {
            self.activeNotification = notification
        }
        
        // Suara notifikasi halus & modern (Purr / Pop / Blow)
        playPleasantNotificationSound()
        
        scheduleAutoDismiss(duration: notification.duration, targetId: notification.id)
    }
    
    /// Menjeda hitung mundur auto-dismiss saat mouse hover
    public func pauseDismiss() {
        guard let notif = activeNotification, !isHoverPaused else { return }
        isHoverPaused = true
        dismissTask?.cancel()
        
        if let start = notificationStartTime {
            let elapsed = Date().timeIntervalSince(start)
            remainingDuration = max(2.0, notif.duration - elapsed)
        }
    }
    
    /// Melanjutkan hitung mundur auto-dismiss saat mouse keluar dari island
    public func resumeDismiss() {
        guard let notif = activeNotification, isHoverPaused else { return }
        isHoverPaused = false
        notificationStartTime = Date()
        scheduleAutoDismiss(duration: remainingDuration, targetId: notif.id)
    }
    
    private func scheduleAutoDismiss(duration: TimeInterval, targetId: UUID) {
        dismissTask?.cancel()
        dismissTask = Task {
            let nanos = UInt64(max(0.5, duration) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    if self.activeNotification?.id == targetId && !self.isHoverPaused {
                        self.activeNotification = nil
                    }
                }
            }
        }
    }
    
    /// Menutup notifikasi aktif seketika (saat tombol 'X' diklik)
    public func dismissActiveNotification() {
        dismissTask?.cancel()
        isHoverPaused = false
        withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
            self.activeNotification = nil
        }
    }
    
    private func playPleasantNotificationSound() {
        if let sound = NSSound(named: "Purr") ?? NSSound(named: "Pop") ?? NSSound(named: "Blow") {
            sound.volume = 0.65
            sound.play()
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
                message: "Liked your story and sent a photo",
                iconSymbol: "camera.fill",
                accentHex: "#E1306C" // Instagram Pink
            )
        case "telegram":
            notif = IslandNotification(
                appName: "Telegram",
                title: "Komunitas Dev ID",
                message: "Swift 6 update preview sudah dirilis cuy!",
                iconSymbol: "paperplane.fill",
                accentHex: "#2AABEE" // Telegram Blue
            )
        default:
            notif = IslandNotification(
                appName: "Sistem",
                title: "Pemberitahuan",
                message: "Notifikasi pengujian berhasil diterima.",
                iconSymbol: "bell.fill",
                accentHex: "#00D2FF"
            )
        }
        postNotification(notif)
    }
}
