import Foundation
import UserNotifications

public final class PrayerNotificationManager {
    public static let shared = PrayerNotificationManager()
    private let center = UNUserNotificationCenter.current()
    
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
    
    /// Menjadwalkan reminder dan notifikasi masuk waktu untuk jadwal hari ini + Subuh hari esok
    public func scheduleAll(
        todaySchedule: PrayerSchedule,
        tomorrowSchedule: PrayerSchedule?,
        preferences: [PrayerName: PrayerPreference]
    ) async {
        // Hapus pending notification lama agar antrean tidak menumpuk dan tidak duplikat
        center.removeAllPendingNotificationRequests()
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        
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
                    content.body = "\(pref.reminderMinutes) menit menuju waktu \(prayer.rawValue) (\(prayerTimeString) WIB)."
                    content.sound = .default
                    
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "ozill-today-reminder-\(prayer.rawValue)",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(request)
                }
            }
            
            // Notifikasi saat masuk waktu shalat
            if prayerDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Waktu \(prayer.rawValue) Telah Tiba"
                content.body = "Sudah masuk waktu shalat \(prayer.rawValue) (\(prayerTimeString)). Mari tunaikan shalat."
                content.sound = .default
                
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "ozill-today-adhan-\(prayer.rawValue)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
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
                        content.body = "\(fajrPref.reminderMinutes) menit menuju waktu Subuh (\(tomorrowFajrString) WIB)."
                        content.sound = .default
                        
                        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        let request = UNNotificationRequest(
                            identifier: "ozill-tomorrow-reminder-Subuh",
                            content: content,
                            trigger: trigger
                        )
                        try? await center.add(request)
                    }
                }
                
                // Waktu Masuk Subuh Besok
                if tomorrowFajr > now {
                    let content = UNMutableNotificationContent()
                    content.title = "Waktu Subuh Telah Tiba"
                    content.body = "Sudah masuk waktu shalat Subuh (\(tomorrowFajrString)). Mari tunaikan shalat."
                    content.sound = .default
                    
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: tomorrowFajr)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "ozill-tomorrow-adhan-Subuh",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(request)
                }
            }
        }
    }
}
