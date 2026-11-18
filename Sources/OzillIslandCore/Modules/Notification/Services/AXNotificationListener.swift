import Foundation
import AppKit
import ApplicationServices

/// Jalur A: Pemantau event banner notifikasi sistem macOS via Accessibility API (AXObserver).
@MainActor
public final class AXNotificationListener: ObservableObject {
    public static let shared = AXNotificationListener()
    
    private var observer: AXObserver?
    private var notificationCenterPID: pid_t?
    private var isObserving: Bool = false
    private var checkTimer: Timer?
    
    public init() {}
    
    public func startListening() {
        guard !isObserving else { return }
        
        guard AXIsProcessTrusted() else {
            NotificationIslandService.shared.checkAccessibilityStatus()
            // Polling berkala jika pengguna nanti memberikan izin di System Settings
            schedulePeriodicPermissionCheck()
            return
        }
        
        NotificationIslandService.shared.checkAccessibilityStatus()
        attachObserverToNotificationCenter()
    }
    
    public func stopListening() {
        if let obs = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
            observer = nil
        }
        isObserving = false
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    private func schedulePeriodicPermissionCheck() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if AXIsProcessTrusted() {
                    self.checkTimer?.invalidate()
                    self.checkTimer = nil
                    NotificationIslandService.shared.checkAccessibilityStatus()
                    self.attachObserverToNotificationCenter()
                }
            }
        }
    }
    
    private func attachObserverToNotificationCenter() {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first ??
                        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.usernoted").first else {
            return
        }
        
        let pid = app.processIdentifier
        self.notificationCenterPID = pid
        
        var newObserver: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            // Menangkap window banner baru yang muncul di notification center
            DispatchQueue.main.async {
                AXNotificationListener.shared.handleAXEvent(element: element)
            }
        }
        
        let err = AXObserverCreate(pid, callback, &newObserver)
        guard err == .success, let obs = newObserver else {
            return
        }
        
        self.observer = obs
        let appElement = AXUIElementCreateApplication(pid)
        
        AXObserverAddNotification(obs, appElement, kAXWindowCreatedNotification as CFString, nil)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        self.isObserving = true
    }
    
    private func handleAXEvent(element: AXUIElement) {
        var titleVal: AnyObject?
        var descVal: AnyObject?
        
        // Baca atribut title dan description dari window/elemen yang baru dibuat
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descVal)
        
        let titleStr = (titleVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let descStr = (descVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Jika ada text terdeteksi
        if !titleStr.isEmpty || !descStr.isEmpty {
            let appName = detectAppName(from: titleStr, desc: descStr)
            let (icon, hex) = styleForApp(appName)
            
            let notif = IslandNotification(
                appName: appName,
                title: titleStr.isEmpty ? appName : titleStr,
                message: descStr.isEmpty ? "Pesan masuk baru" : descStr,
                iconSymbol: icon,
                accentHex: hex
            )
            NotificationIslandService.shared.postNotification(notif)
        }
    }
    
    private func detectAppName(from title: String, desc: String) -> String {
        let combined = "\(title) \(desc)".lowercased()
        if combined.contains("whatsapp") { return "WhatsApp" }
        if combined.contains("instagram") { return "Instagram" }
        if combined.contains("telegram") { return "Telegram" }
        if combined.contains("slack") { return "Slack" }
        if combined.contains("mail") { return "Mail" }
        if combined.contains("discord") { return "Discord" }
        return "Notifikasi"
    }
    
    private func styleForApp(_ app: String) -> (String, String) {
        switch app.lowercased() {
        case "whatsapp": return ("message.fill", "#25D366")
        case "instagram": return ("camera.fill", "#E1306C")
        case "telegram": return ("paperplane.fill", "#2AABEE")
        case "slack": return ("number", "#4A154B")
        case "mail": return ("envelope.fill", "#007AFF")
        case "discord": return ("bubble.left.and.bubble.right.fill", "#5865F2")
        default: return ("bell.fill", "#00D2FF")
        }
    }
}
