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
    
    /// Menjadwalkan reminder dan notifikasi masuk waktu untuk jadwal shalat
    public func scheduleAll(schedule: PrayerSchedule, preferences: [PrayerName: PrayerPreference]) async {
        // Hapus pending notification lama agar tidak menumpuk
        center.removeAllPendingNotificationRequests()
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        
        for prayer in PrayerName.fardhuPrayers {
            let pref = preferences[prayer] ?? PrayerPreference()
            guard pref.enabled else { continue }
            
            let prayerDate = schedule.time(for: prayer)
            let prayerTimeString = formatter.string(from: prayerDate)
            
            // 1. Reminder Menjelang Shalat (misal 10 atau 15 menit sebelumnya)
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
                        identifier: "ozill-reminder-\(prayer.rawValue)",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(request)
                }
            }
            
            // 2. Notifikasi Saat Masuk Waktu Shalat
            if prayerDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Waktu \(prayer.rawValue) Telah Tiba"
                content.body = "Sudah masuk waktu shalat \(prayer.rawValue) (\(prayerTimeString)). Mari tunaikan shalat."
                content.sound = .default
                
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "ozill-athan-\(prayer.rawValue)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }
}
