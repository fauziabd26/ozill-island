import Foundation
import AppKit
import ApplicationServices

/// Jalur A: Pemantau event banner notifikasi sistem macOS via Accessibility API & Window Inspection.
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
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Perbarui status izin
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
            "com.apple.UserNotificationCenter",
            "com.apple.notificationcenterui"
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
    
    /// Polling berkala terhadap window banner aktif
    private func pollActiveNotificationWindows() {
        let cutoff = Date().addingTimeInterval(-15.0)
        recentBannerHashes = recentBannerHashes.filter { $0.value > cutoff }
        
        let bundleIDs = [
            "com.apple.UserNotificationCenter",
            "com.apple.notificationcenterui"
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
        extractTexts(from: element, depth: 0, maxDepth: 3, results: &texts)
        
        let combined = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !combined.isEmpty else { return }
        
        let hash = combined
        if let last = recentBannerHashes[hash], Date().timeIntervalSince(last) < 6.0 {
            return
        }
        recentBannerHashes[hash] = Date()
        
        let titleStr = texts.first ?? "Notifikasi"
        let descStr = texts.count > 1 ? texts.dropFirst().joined(separator: " - ") : "Pesan masuk baru"
        
        let appName = detectAppName(from: titleStr, desc: descStr)
        let (icon, hex) = styleForApp(appName)
        
        let notif = IslandNotification(
            appName: appName,
            title: titleStr,
            message: descStr,
            iconSymbol: icon,
            accentHex: hex,
            duration: 5.0
        )
        NotificationIslandService.shared.postNotification(notif)
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
        if let d = (descVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty, !results.contains(d) {
            results.append(d)
        }
        
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for child in children.prefix(8) {
                extractTexts(from: child, depth: depth + 1, maxDepth: maxDepth, results: &results)
            }
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
        return "Notifikasi Sistem"
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
