import Foundation
import UserNotifications

public extension TimeZone {
    /// Memberikan singkatan zona waktu yang deterministik untuk wilayah Indonesia
    var indonesianAbbreviation: String {
        switch identifier {
        case "Asia/Jakarta", "Asia/Pontianak":
            return "WIB"
        case "Asia/Makassar", "Asia/Ujung_Pandang", "Asia/Denpasar":
            return "WITA"
        case "Asia/Jayapura":
            return "WIT"
        default:
            return abbreviation() ?? identifier
        }
    }
}

/// Mengelola antrean notifikasi lokal macOS untuk pengingat dan waktu masuk shalat.
/// Menggunakan aktor Swift dengan pembatalan Task dan revision token serial untuk mencegah race condition antar Task yang berjalan paralel.
public actor PrayerNotificationManager {
    public static let shared = PrayerNotificationManager()
    private let center = UNUserNotificationCenter.current()
    private var currentSchedulingRevision: UInt64 = 0
    
    public init() {}
    
    @discardableResult
    public func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("PrayerNotificationManager: Permission error -", error)
            return false
        }
    }
    
    /// Menjadwalkan reminder dan notifikasi masuk waktu untuk jadwal hari ini + Subuh hari esok.
    /// Dilindungi dengan revision token dan Task cancellation check di setiap suspension point.
    public func scheduleAll(
        todaySchedule: PrayerSchedule,
        tomorrowSchedule: PrayerSchedule?,
        preferences: [PrayerName: PrayerPreference],
        timeZone: TimeZone = .current
    ) async {
        currentSchedulingRevision &+= 1
        let thisRevision = currentSchedulingRevision
        
        guard !Task.isCancelled else { return }
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        let tzAbbr = timeZone.indonesianAbbreviation
        
        var pendingRequests: [UNNotificationRequest] = []
        
        // 1. Jadwal Hari Ini
        for prayer in PrayerName.fardhuPrayers {
            let pref = preferences[prayer] ?? PrayerPreference()
            guard pref.enabled else { continue }
            
            let prayerDate = todaySchedule.time(for: prayer)
            let prayerTimeString = formatter.string(from: prayerDate)
            
            // Pengingat sebelum shalat
            if pref.reminderMinutes > 0 {
                let reminderDate = prayerDate.addingTimeInterval(-Double(pref.reminderMinutes * 60))
                if reminderDate > now {
                    let content = UNMutableNotificationContent()
                    content.title = "Pengingat Shalat \(prayer.rawValue)"
                    content.body = "\(pref.reminderMinutes) menit menuju waktu \(prayer.rawValue) (\(prayerTimeString) \(tzAbbr))."
                    content.sound = .default
                    
                    var cal = Calendar(identifier: .gregorian)
                    cal.timeZone = timeZone
                    let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "ozill-today-reminder-\(prayer.rawValue)",
                        content: content,
                        trigger: trigger
                    )
                    pendingRequests.append(request)
                }
            }
            
            // Notifikasi saat masuk waktu shalat
            if prayerDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Waktu \(prayer.rawValue) Telah Tiba"
                content.body = "Sudah masuk waktu shalat \(prayer.rawValue) (\(prayerTimeString) \(tzAbbr)). Mari tunaikan shalat."
                content.sound = .default
                
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = timeZone
                let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "ozill-today-adhan-\(prayer.rawValue)",
                    content: content,
                    trigger: trigger
                )
                pendingRequests.append(request)
            }
        }
        
        // 2. Jadwal Subuh Besok (Untuk antisipasi Mac sleep semalaman)
        if let tomorrow = tomorrowSchedule {
            let fajrPref = preferences[.fajr] ?? PrayerPreference()
            if fajrPref.enabled {
                let tomorrowFajr = tomorrow.fajr
                let tomorrowFajrString = formatter.string(from: tomorrowFajr)
                
                // Reminder Subuh Besok
                if fajrPref.reminderMinutes > 0 {
                    let reminderDate = tomorrowFajr.addingTimeInterval(-Double(fajrPref.reminderMinutes * 60))
                    if reminderDate > now {
                        let content = UNMutableNotificationContent()
                        content.title = "Pengingat Shalat Subuh Besok"
                        content.body = "\(fajrPref.reminderMinutes) menit menuju waktu Subuh (\(tomorrowFajrString) \(tzAbbr))."
                        content.sound = .default
                        
                        var cal = Calendar(identifier: .gregorian)
                        cal.timeZone = timeZone
                        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        let request = UNNotificationRequest(
                            identifier: "ozill-tomorrow-reminder-Subuh",
                            content: content,
                            trigger: trigger
                        )
                        pendingRequests.append(request)
                    }
                }
                
                // Waktu Masuk Subuh Besok
                if tomorrowFajr > now {
                    let content = UNMutableNotificationContent()
                    content.title = "Waktu Subuh Telah Tiba"
                    content.body = "Sudah masuk waktu shalat Subuh (\(tomorrowFajrString) \(tzAbbr)). Mari tunaikan shalat."
                    content.sound = .default
                    
                    var cal = Calendar(identifier: .gregorian)
                    cal.timeZone = timeZone
                    let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: tomorrowFajr)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "ozill-tomorrow-adhan-Subuh",
                        content: content,
                        trigger: trigger
                    )
                    pendingRequests.append(request)
                }
            }
        }
        
        // Cek revision token & cancellation sebelum memodifikasi notification center
        guard !Task.isCancelled && thisRevision == self.currentSchedulingRevision else {
            return
        }
        
        // Hapus pending lama
        center.removeAllPendingNotificationRequests()
        
        // Daftarkan notifikasi baru dengan verifikasi revision di setiap iterasi
        for req in pendingRequests {
            guard !Task.isCancelled && thisRevision == self.currentSchedulingRevision else { return }
            try? await center.add(req)
        }
    }
}
