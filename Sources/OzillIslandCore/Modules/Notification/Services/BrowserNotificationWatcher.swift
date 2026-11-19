import Foundation
import AppKit

/// Jalur B: Pemantau badge, pesan masuk baru, dan event web notification di browser (Chrome, Edge, Safari).
@MainActor
public final class BrowserNotificationWatcher: ObservableObject {
    public static let shared = BrowserNotificationWatcher()
    
    private var timer: Timer?
    private var isChecking: Bool = false
    
    /// Menyimpan state per tab menggunakan key unik: `\(browser)::\(url)`
    private var lastRecordedCounts: [String: Int] = [:]
    private var lastRecordedTitles: [String: String] = [:]
    private var lastDOMFingerprints: [String: String] = [:]
    
    /// Cache deduplikasi pesan (hash pesan -> tanggal terakhir diposting)
    private var recentNotificationTimestamps: [String: Date] = [:]
    
    public init() {}
    
    public func startWatching() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkBrowserTabs()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }
    
    public func stopWatching() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Memeriksa tab browser aktif untuk mendeteksi pesan masuk di WhatsApp Web, Instagram, dan Telegram.
    public func checkBrowserTabs() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        
        // Bersihkan cache deduplikasi yang lebih tua dari 15 detik
        let cutoff = Date().addingTimeInterval(-15.0)
        recentNotificationTimestamps = recentNotificationTimestamps.filter { $0.value > cutoff }
        
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
                set res to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set u to URL of t
                            set tit to name of t
                            if u contains "whatsapp.com" or u contains "instagram.com" or u contains "telegram.org" then
                                set res to res & u & ":::OZILL_FIELD:::" & tit & ":::OZILL_FIELD:::|||OZILL_RECORD|||"
                            end if
                        end try
                    end repeat
                end repeat
                return res
            end tell
            """
        } else {
            // Google Chrome & Microsoft Edge
            script = """
            tell application "\(browserName)"
                set res to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set u to URL of t
                            set tit to title of t
                            if u contains "whatsapp.com" or u contains "instagram.com" or u contains "telegram.org" then
                                set jsRes to ""
                                try
                                    set js to "(() => {
                                        if (!window.__ozill_installed) {
                                            window.__ozill_installed = true;
                                            window.__ozill_notifs = [];
                                            const orig = window.Notification;
                                            if (orig) {
                                                window.Notification = function(title, opt) {
                                                    window.__ozill_notifs.push({
                                                        title: title || '',
                                                        body: opt?.body || '',
                                                        time: Date.now()
                                                    });
                                                    try { return new orig(title, opt); } catch(e) { return {}; }
                                                };
                                                window.Notification.permission = orig.permission;
                                                window.Notification.requestPermission = orig.requestPermission ? orig.requestPermission.bind(orig) : undefined;
                                            }
                                        }
                                        const queued = window.__ozill_notifs ? window.__ozill_notifs.splice(0) : [];
                                        let domSender = '';
                                        let domMsg = '';
                                        let hasUnread = false;
                                        const side = document.getElementById('pane-side');
                                        if (side) {
                                            const unreadBadges = side.querySelectorAll(\\"span[aria-label*='unread'], span[aria-label*='belum dibaca'], [data-icon='unread-count'], span[aria-label*='pesan belum']\\");
                                            if (unreadBadges.length > 0) {
                                                hasUnread = true;
                                                const chatRow = unreadBadges[0].closest(\\"div[role='listitem'], div[role='row']\\");
                                                if (chatRow) {
                                                    const titleElem = chatRow.querySelector(\\"[data-testid='cell-frame-title'] span\\");
                                                    const msgElem = chatRow.querySelector(\\"[data-testid='cell-frame-secondary'] span[dir='ltr']\\");
                                                    domSender = titleElem ? (titleElem.getAttribute('title') || titleElem.innerText) : '';
                                                    domMsg = msgElem ? msgElem.innerText : 'Pesan baru masuk';
                                                }
                                            }
                                        }
                                        return JSON.stringify({
                                            title: document.title,
                                            queued: queued,
                                            hasUnread: hasUnread,
                                            domSender: domSender,
                                            domMsg: domMsg
                                        });
                                    })()"
                                    set jsRes to (execute t javascript js)
                                end try
                                set res to res & u & ":::OZILL_FIELD:::" & tit & ":::OZILL_FIELD:::" & jsRes & "|||OZILL_RECORD|||"
                            end if
                        end try
                    end repeat
                end repeat
                return res
            end tell
            """
        }
        
        let (success, output) = await ScriptBridge.executeAppleScript(script, timeout: 2.0)
        guard success, !output.isEmpty else { return }
        
        parseBrowserOutput(output, browserName: browserName)
    }
    
    private func parseBrowserOutput(_ output: String, browserName: String) {
        let records = output.components(separatedBy: "|||OZILL_RECORD|||")
        for record in records {
            let fields = record.components(separatedBy: ":::OZILL_FIELD:::")
            guard fields.count >= 2 else { continue }
            
            let url = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { continue }
            
            let jsPayload = fields.count >= 3 ? fields[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let cacheKey = "\(browserName)::\(url)"
            
            // 1. Ekstraksi dari JS Payload jika tersedia (intersepsi window.Notification & DOM Chat)
            if !jsPayload.isEmpty, let data = jsPayload.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // A. Notifikasi Web asli (window.Notification)
                if let queued = json["queued"] as? [[String: Any]], !queued.isEmpty {
                    for item in queued {
                        let notifTitle = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let notifBody = (item["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if !notifTitle.isEmpty || !notifBody.isEmpty {
                            dispatchNotification(
                                appName: determineAppName(from: url),
                                title: notifTitle.isEmpty ? determineAppName(from: url) : notifTitle,
                                message: notifBody.isEmpty ? "Pesan baru masuk" : notifBody,
                                url: url
                            )
                        }
                    }
                }
                
                // B. Deteksi chat unread dari DOM WhatsApp Web (#pane-side)
                let hasUnread = (json["hasUnread"] as? Bool) ?? false
                let domSender = (json["domSender"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let domMsg = (json["domMsg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if hasUnread && !domSender.isEmpty {
                    let domFingerprint = "\(domSender):::\(domMsg)"
                    let prevFingerprint = lastDOMFingerprints[cacheKey]
                    if prevFingerprint != domFingerprint {
                        lastDOMFingerprints[cacheKey] = domFingerprint
                        dispatchNotification(
                            appName: determineAppName(from: url),
                            title: domSender,
                            message: domMsg.isEmpty ? "Pesan baru masuk" : domMsg,
                            url: url
                        )
                    }
                } else if !hasUnread {
                    lastDOMFingerprints.removeValue(forKey: cacheKey)
                }
            }
            
            // 2. Evaluasi Tab Title (Fallback untuk Safari, Edge, dan background tab)
            evaluateTabTitle(title: title, url: url, cacheKey: cacheKey)
        }
    }
    
    private func evaluateTabTitle(title: String, url: String, cacheKey: String) {
        guard !title.isEmpty else { return }
        
        let prevTitle = lastRecordedTitles[cacheKey]
        lastRecordedTitles[cacheKey] = title
        
        // Cari angka unread badge: "(1)", "[2]", "(99+)", atau "Telegram (1)"
        var currentCount: Int? = nil
        if let regex = try? NSRegularExpression(pattern: #"[\(\[](\d+)\+?[\)\]]"#),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let countRange = Range(match.range(at: 1), in: title) {
            currentCount = Int(title[countRange])
        }
        
        let prevCount = lastRecordedCounts[cacheKey]
        if let count = currentCount {
            lastRecordedCounts[cacheKey] = count
            
            // Jika unread count bertambah dari sebelumnya
            if let p = prevCount, count > p {
                let sender = extractSenderFromTitle(title, url: url)
                dispatchNotification(
                    appName: determineAppName(from: url),
                    title: sender ?? "\(count) Pesan Belum Dibaca",
                    message: "Ada pesan baru masuk di \(determineAppName(from: url))",
                    url: url
                )
            } else if prevCount == nil && count > 0 {
                // Inisialisasi awal saat baru start app: catat tanpa membanjiri notifikasi lama
            }
        } else {
            // Title tidak memiliki badge angka (misal chat sudah dibaca)
            lastRecordedCounts[cacheKey] = 0
        }
        
        // Jika title berubah nama kontak secara eksplisit (misal: "WhatsApp" -> "(1) Budi: halo")
        if let prev = prevTitle, prev != title {
            if let sender = extractSenderFromTitle(title, url: url), !prev.contains(sender) {
                dispatchNotification(
                    appName: determineAppName(from: url),
                    title: sender,
                    message: "Pesan baru masuk",
                    url: url
                )
            }
        }
    }
    
    private func extractSenderFromTitle(_ title: String, url: String) -> String? {
        // Pola: "(1) Budi Santoso - WhatsApp" atau "(1) Budi: halo"
        let cleaned = title.replacingOccurrences(of: #"[\(\[]\d+\+?[\)\]]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "- WhatsApp", with: "")
            .replacingOccurrences(of: "• Instagram", with: "")
            .replacingOccurrences(of: "WhatsApp", with: "")
            .replacingOccurrences(of: "Instagram", with: "")
            .replacingOccurrences(of: "Telegram", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-:•| "))
        
        return cleaned.isEmpty ? nil : cleaned
    }
    
    private func determineAppName(from url: String) -> String {
        if url.contains("whatsapp.com") { return "WhatsApp" }
        if url.contains("instagram.com") { return "Instagram" }
        if url.contains("telegram.org") { return "Telegram" }
        return "Web Notification"
    }
    
    private func dispatchNotification(appName: String, title: String, message: String, url: String) {
        let (icon, hex) = styleForApp(appName)
        let fingerprint = "\(appName):::\(title):::\(message)"
        
        // Anti-spam deduplication: jangan tampilkan pesan identik dalam interval 4 detik
        if let lastTime = recentNotificationTimestamps[fingerprint], Date().timeIntervalSince(lastTime) < 4.0 {
            return
        }
        recentNotificationTimestamps[fingerprint] = Date()
        
        let notif = IslandNotification(
            appName: appName,
            title: title,
            message: message,
            iconSymbol: icon,
            accentHex: hex,
            duration: 5.0
        )
        NotificationIslandService.shared.postNotification(notif)
    }
    
    private func styleForApp(_ app: String) -> (String, String) {
        switch app.lowercased() {
        case "whatsapp": return ("message.fill", "#25D366")
        case "instagram": return ("camera.fill", "#E1306C")
        case "telegram": return ("paperplane.fill", "#2AABEE")
        default: return ("bell.fill", "#00D2FF")
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
