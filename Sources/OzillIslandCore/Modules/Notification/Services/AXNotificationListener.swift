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
            // Hanya tangkap event kemunculan window baru (banner notification baru)
            // JANGAN pasang kAXValueChangedNotification karena akan terpanggil setiap detik/menit saat jam & tanggal sistem berubah!
            AXObserverAddNotification(obs, appElement, kAXWindowCreatedNotification as CFString, nil)

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
                // Saring window sistem agar bukan widget atau menu bar item
                var subroleVal: AnyObject?
                AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subroleVal)
                if let subrole = subroleVal as? String {
                    let subLower = subrole.lowercased()
                    if subLower.contains("widget") || subLower.contains("dialog") || subLower.contains("menu") {
                        continue
                    }
                }
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
        let parsed = parseNotificationTexts(texts)

        // FILTER NOISE: Tolak tegas jika teks adalah jam (clock), tanggal (date), kalender, atau widget
        if isSystemNoise(texts: texts, appName: parsed.appName, title: parsed.title) {
            return
        }

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

    /// Filter ketat untuk membuang teks derau sistem seperti jam (clock), tanggal (date),
    /// kalender, cuaca, dan widget latar belakang macOS agar tidak memicu notifikasi palsu.
    public func isSystemNoise(texts: [String], appName: String, title: String) -> Bool {
        let appLower = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let titleLower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Blacklist kata kunci widget & jam sistem
        let noisyKeywords = [
            "clock", "jam", "waktu", "time",
            "date", "tanggal",
            "calendar", "kalender",
            "weather", "cuaca",
            "notification center", "pusat pemberitahuan",
            "control center", "pusat kontrol",
            "widgets", "widget", "edit widgets",
            "stocks", "saham",
            "battery", "baterai",
            "screen time", "durasi layar",
            "now playing", "sedang memutar", "sedang diputar"
        ]

        if noisyKeywords.contains(titleLower) || noisyKeywords.contains(appLower) {
            return true
        }

        // 2. Deteksi teks yang murni format waktu (misal "15:10", "03:45 PM", "12.30")
        let timePattern = #"^(\d{1,2}[:.]\d{2}([:.]\d{2})?(\s?(am|pm|wib|wita|wit))?)$"#
        if titleLower.range(of: timePattern, options: .regularExpression) != nil {
            return true
        }

        // 3. Deteksi teks yang seluruh katanya hanya nama hari, bulan, angka tanggal, atau jam
        let dayNames: Set<String> = [
            "senin", "selasa", "rabu", "kamis", "jumat", "sabtu", "minggu",
            "mon", "tue", "wed", "thu", "fri", "sat", "sun",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
        ]
        let monthNames: Set<String> = [
            "januari", "februari", "maret", "april", "mei", "juni", "juli", "agustus", "september", "oktober", "november", "desember",
            "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
            "january", "february", "march", "april", "june", "july", "august", "september", "october", "december"
        ]

        let words = texts.flatMap {
            $0.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        }.filter { !$0.isEmpty }

        if !words.isEmpty {
            let isAllCalendarNoise = words.allSatisfy { word in
                dayNames.contains(word) || monthNames.contains(word) || Int(word) != nil || noisyKeywords.contains(word)
            }
            if isAllCalendarNoise {
                return true
            }
        }

        // 4. Jika appName adalah "Notifikasi Sistem" tanpa judul alert yang relevan
        if appLower == "notifikasi sistem" {
            if titleLower.isEmpty || titleLower == "notifikasi sistem" || titleLower.count < 3 {
                return true
            }
        }

        return false
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
