import Foundation
import AppKit

/// Jalur B: Pemantau badge dan pesan baru di tab web browser (WhatsApp Web, Instagram, Telegram).
@MainActor
public final class BrowserNotificationWatcher: ObservableObject {
    public static let shared = BrowserNotificationWatcher()
    
    private var timer: Timer?
    private var lastRecordedCounts: [String: Int] = [:]
    private var isChecking: Bool = false
    
    public init() {}
    
    public func startWatching() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkBrowserTabs()
            }
        }
    }
    
    public func stopWatching() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Memeriksa tab browser aktif untuk mendeteksi title bertanda `(1) WhatsApp` dsb.
    public func checkBrowserTabs() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        
        let browsers = ["Google Chrome", "Microsoft Edge", "Safari"]
        for browser in browsers {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdForBrowser(browser)).isEmpty else {
                continue
            }
            await scanBrowser(browser)
        }
    }
    
    private func scanBrowser(_ browserName: String) async {
        let script: String
        if browserName == "Safari" {
            script = """
            tell application "Safari"
                set res to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set u to URL of t
                            set tit to name of t
                            if u contains "whatsapp.com" or u contains "instagram.com" or u contains "telegram.org" then
                                set end of res to u & ":::" & tit
                            end if
                        end try
                    end repeat
                end repeat
                return res
            end tell
            """
        } else {
            script = """
            tell application "\(browserName)"
                set res to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set u to URL of t
                            set tit to title of t
                            if u contains "whatsapp.com" or u contains "instagram.com" or u contains "telegram.org" then
                                set end of res to u & ":::" & tit
                            end if
                        end try
                    end repeat
                end repeat
                return res
            end tell
            """
        }
        
        let (success, output) = await ScriptBridge.executeAppleScript(script, timeout: 1.2)
        guard success, !output.isEmpty else { return }
        
        parseBrowserOutput(output)
    }
    
    private func parseBrowserOutput(_ output: String) {
        let items = output.components(separatedBy: ", ")
        for item in items {
            let parts = item.components(separatedBy: ":::")
            guard parts.count >= 2 else { continue }
            let url = parts[0]
            let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Regex mencari pola: "(2) WhatsApp" atau "(1) Instagram"
            if let regex = try? NSRegularExpression(pattern: #"^\((\d+)\)\s*(.*)"#),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
               let countRange = Range(match.range(at: 1), in: title) {
                
                let countStr = String(title[countRange])
                let count = Int(countStr) ?? 0
                let cacheKey = url
                let prevCount = lastRecordedCounts[cacheKey] ?? 0
                
                // Jika unread count bertambah dari sebelumnya
                if count > prevCount {
                    let appName: String
                    let icon: String
                    let hex: String
                    
                    if url.contains("whatsapp.com") {
                        appName = "WhatsApp Web"
                        icon = "message.fill"
                        hex = "#25D366"
                    } else if url.contains("instagram.com") {
                        appName = "Instagram"
                        icon = "camera.fill"
                        hex = "#E1306C"
                    } else {
                        appName = "Telegram Web"
                        icon = "paperplane.fill"
                        hex = "#2AABEE"
                    }
                    
                    let notif = IslandNotification(
                        appName: appName,
                        title: "\(count) Pesan Belum Dibaca",
                        message: "Ada pesan baru masuk di tab \(appName)",
                        iconSymbol: icon,
                        accentHex: hex
                    )
                    NotificationIslandService.shared.postNotification(notif)
                }
                
                lastRecordedCounts[cacheKey] = count
            }
        }
    }
    
    private func bundleIdForBrowser(_ name: String) -> String {
        switch name {
        case "Google Chrome": return "com.google.Chrome"
        case "Microsoft Edge": return "com.microsoft.edgemac"
        case "Safari": return "com.apple.Safari"
        default: return ""
        }
    }
}
