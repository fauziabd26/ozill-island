import Foundation
import AppKit
import ApplicationServices

/// Jalur A: Pemantau event banner notifikasi sistem macOS (termasuk WhatsApp, iPhone Mirroring, Telegram, Mail) via Accessibility API & Window Inspection.
@MainActor
public final class AXNotificationListener: ObservableObject {
    public static let shared = AXNotificationListener()
    
    private var observers: [AXObserver] = []
    private var isObserving: Bool = false
    private var pollTimer: Timer?
    
    /// Deduplikasi event sistem agar tidak berulang
    private var recentBannerHashes: [String: Date] = [:]
    
    public init() {}
    
    public func startListening() {
        guard !isObserving else { return }
        
        NotificationIslandService.shared.checkAccessibilityStatus()
        
        if AXIsProcessTrusted() {
            attachObservers()
        } else {
            // Minta izin ke macOS agar aplikasi terdaftar di System Settings -> Privacy & Security -> Accessibility
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options)
        }
        
        startPeriodicPolling()
        self.isObserving = true
    }
    
    public func stopListening() {
        for obs in observers {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        }
        observers.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
        isObserving = false
    }
    
    private func startPeriodicPolling() {
        pollTimer?.invalidate()
        // Polling setiap 0.8 detik untuk responsivitas instan menangkap banner sistem
        let t = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let trusted = AXIsProcessTrusted()
                if trusted != NotificationIslandService.shared.isAccessibilityGranted {
                    NotificationIslandService.shared.checkAccessibilityStatus()
                    if trusted && self.observers.isEmpty {
                        self.attachObservers()
                    }
                }
                
                guard trusted else { return }
                self.pollActiveNotificationWindows()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.pollTimer = t
    }
    
    private func attachObservers() {
        let bundleIDs = [
            "com.apple.notificationcenterui",
            "com.apple.UserNotificationCenter"
        ]
        
        for bundleID in bundleIDs {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
                continue
            }
            
            let pid = app.processIdentifier
            var newObserver: AXObserver?
            let callback: AXObserverCallback = { observer, element, notification, refcon in
                DispatchQueue.main.async {
                    AXNotificationListener.shared.handleAXEvent(element: element)
                }
            }
            
            let err = AXObserverCreate(pid, callback, &newObserver)
            guard err == .success, let obs = newObserver else { continue }
            
            let appElement = AXUIElementCreateApplication(pid)
            AXObserverAddNotification(obs, appElement, kAXWindowCreatedNotification as CFString, nil)
            AXObserverAddNotification(obs, appElement, kAXFocusedUIElementChangedNotification as CFString, nil)
            AXObserverAddNotification(obs, appElement, kAXValueChangedNotification as CFString, nil)
            
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
            self.observers.append(obs)
        }
    }
    
    /// Polling berkala terhadap window banner aktif milik Notification Center
    public func pollActiveNotificationWindows() {
        let cutoff = Date().addingTimeInterval(-10.0)
        recentBannerHashes = recentBannerHashes.filter { $0.value > cutoff }
        
        let bundleIDs = [
            "com.apple.notificationcenterui",
            "com.apple.UserNotificationCenter"
        ]
        
        for bundleID in bundleIDs {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
                continue
            }
            let appElem = AXUIElementCreateApplication(app.processIdentifier)
            var windowsVal: AnyObject?
            let err = AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsVal)
            guard err == .success, let windows = windowsVal as? [AXUIElement] else { continue }
            
            for win in windows {
                handleAXEvent(element: win)
            }
        }
    }
    
    private func handleAXEvent(element: AXUIElement) {
        var texts: [String] = []
        extractTexts(from: element, depth: 0, maxDepth: 10, results: &texts)
        
        // Hapus teks bawaan sistem seperti "Notification Center"
        texts.removeAll { $0.lowercased() == "notification center" || $0.isEmpty }
        guard !texts.isEmpty else { return }
        
        let combined = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard combined.count >= 2 else { return }
        
        // Cek deduplikasi agar banner yang masih tampil tidak memicu posting berulang
        if let last = recentBannerHashes[combined], Date().timeIntervalSince(last) < 7.0 {
            return
        }
        recentBannerHashes[combined] = Date()
        
        // Ekstraksi terstruktur untuk notifikasi sistem & iPhone Mirroring:
        // Pola umum: [AppName, Sender/Contact, Subtitle/Message, Body...]
        let parsed = parseNotificationTexts(texts)
        let (icon, hex) = styleForApp(parsed.appName)
        
        let notif = IslandNotification(
            appName: parsed.appName,
            title: parsed.title,
            message: parsed.message,
            iconSymbol: icon,
            accentHex: hex,
            duration: 5.0
        )
        NotificationIslandService.shared.postNotification(notif)
    }
    
    private func parseNotificationTexts(_ texts: [String]) -> (appName: String, title: String, message: String) {
        // Daftar nama aplikasi umum
        let knownApps = ["whatsapp", "instagram", "telegram", "slack", "mail", "discord", "messages", "pesan"]
        
        var foundAppIndex: Int? = nil
        var detectedAppName = "Notifikasi Sistem"
        
        for (i, t) in texts.enumerated() {
            let lower = t.lowercased()
            for ka in knownApps {
                if lower.contains(ka) {
                    foundAppIndex = i
                    detectedAppName = capitalizeAppName(ka)
                    break
                }
            }
            if foundAppIndex != nil { break }
        }
        
        var remaining = texts
        if let idx = foundAppIndex {
            remaining.remove(at: idx)
        }
        
        let title: String
        let message: String
        
        if remaining.isEmpty {
            title = detectedAppName
            message = "Pesan baru masuk"
        } else if remaining.count == 1 {
            title = remaining[0]
            message = "Pesan baru masuk"
        } else {
            title = remaining[0]
            message = remaining.dropFirst().joined(separator: " • ")
        }
        
        return (appName: detectedAppName, title: title, message: message)
    }
    
    private func capitalizeAppName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "whatsapp": return "WhatsApp"
        case "instagram": return "Instagram"
        case "telegram": return "Telegram"
        case "slack": return "Slack"
        case "mail": return "Mail"
        case "discord": return "Discord"
        case "messages", "pesan": return "Pesan"
        default: return raw.capitalized
        }
    }
    
    private func extractTexts(from element: AXUIElement, depth: Int, maxDepth: Int, results: inout [String]) {
        guard depth <= maxDepth else { return }
        
        var titleVal: AnyObject?
        var valVal: AnyObject?
        var descVal: AnyObject?
        
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valVal)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descVal)
        
        if let t = (titleVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, !results.contains(t) {
            results.append(t)
        }
        if let v = (valVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty, !results.contains(v) {
            results.append(v)
        }
        if let d = (descVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            // Jika desc berupa daftar teks yang dipisahkan koma (khas AXGroup banner)
            if d.contains(",") {
                let parts = d.components(separatedBy: ", ")
                for p in parts {
                    let cleaned = p.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty && !results.contains(cleaned) {
                        results.append(cleaned)
                    }
                }
            } else if !results.contains(d) {
                results.append(d)
            }
        }
        
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for child in children.prefix(12) {
                extractTexts(from: child, depth: depth + 1, maxDepth: maxDepth, results: &results)
            }
        }
    }
    
    private func styleForApp(_ app: String) -> (String, String) {
        switch app.lowercased() {
        case "whatsapp": return ("message.fill", "#25D366")
        case "instagram": return ("camera.fill", "#E1306C")
        case "telegram": return ("paperplane.fill", "#2AABEE")
        case "slack": return ("number", "#4A154B")
        case "mail": return ("envelope.fill", "#007AFF")
        case "discord": return ("bubble.left.and.bubble.right.fill", "#5865F2")
        case "pesan", "messages": return ("bubble.left.fill", "#34C759")
        default: return ("bell.fill", "#00D2FF")
        }
    }
}
