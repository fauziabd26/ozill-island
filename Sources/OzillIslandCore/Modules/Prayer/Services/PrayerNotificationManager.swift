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

/// Protokol abstraksi notification center untuk memungkinkan pengujian deterministik dan mock
public protocol PrayerNotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func removeAllPendingNotificationRequests() async
    func add(_ request: UNNotificationRequest) async throws
}

/// Adapter default membungkus UNUserNotificationCenter bawaan macOS secara aman.
/// Jika dijalankan di environment non-app bundle (misal CLI unit test runner), adapter
/// secara graceful menjadi no-op tanpa memicu fatal assertion UNUserNotificationCenter.
public final class DefaultNotificationCenterAdapter: PrayerNotificationCenterProtocol, @unchecked Sendable {
    private let center: UNUserNotificationCenter?
    public init(center: UNUserNotificationCenter? = nil) {
        if let center = center {
            self.center = center
        } else if Bundle.main.bundleIdentifier != nil {
            self.center = UNUserNotificationCenter.current()
        } else {
            self.center = nil
        }
    }
    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        guard let center = center else { return false }
        return try await center.requestAuthorization(options: options)
    }
    public func removeAllPendingNotificationRequests() async {
        guard let center = center else { return }
        center.removeAllPendingNotificationRequests()
    }
    public func add(_ request: UNNotificationRequest) async throws {
        guard let center = center else { return }
        try await center.add(request)
    }
}

/// Mengelola antrean notifikasi lokal macOS untuk pengingat dan waktu masuk shalat.
/// Menggunakan aktor Swift dengan FIFO serialized scheduling queue dan revision token
/// untuk mencegah race condition dan actor re-entrancy overlapping saat Mac beroperasi.
public actor PrayerNotificationManager {
    public static let shared = PrayerNotificationManager()
    private let center: PrayerNotificationCenterProtocol
    private var currentSchedulingRevision: UInt64 = 0
    private var ongoingTask: Task<Void, Never>?
    public private(set) var lastErrors: [(identifier: String, error: String)] = []
    
    public init(center: PrayerNotificationCenterProtocol = DefaultNotificationCenterAdapter()) {
        self.center = center
    }
    
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
    
    /// Mengosongkan daftar error yang tercatat (untuk diagnostik)
    public func clearErrors() {
        lastErrors.removeAll()
    }
    
    /// Membaca nomor revisi penjadwalan saat ini
    public func getRevision() -> UInt64 {
        return currentSchedulingRevision
    }
    
    /// Menjadwalkan reminder dan notifikasi masuk waktu untuk jadwal hari ini + Subuh hari esok.
    /// Dilindungi antrean eksekusi serial FIFO sehingga batch baru tidak akan pernah
    /// tumpang tindih dengan batch lama yang sedang dalam suspension point.
    public func scheduleAll(
        todaySchedule: PrayerSchedule,
        tomorrowSchedule: PrayerSchedule?,
        preferences: [PrayerName: PrayerPreference],
        timeZone: TimeZone = .current
    ) async {
        currentSchedulingRevision &+= 1
        let thisRevision = currentSchedulingRevision
        
        let previous = ongoingTask
        let newTask = Task { [previous] in
            // 1. Tunggu operasi batch lama selesai secara penuh sebelum batch baru mulai memodifikasi notifikasi
            _ = await previous?.result
            
            // 2. Jalankan proses penjadwalan batch ini
            await self.executeSchedule(
                revision: thisRevision,
                todaySchedule: todaySchedule,
                tomorrowSchedule: tomorrowSchedule,
                preferences: preferences,
                timeZone: timeZone
            )
        }
        ongoingTask = newTask
        await newTask.value
    }
    
    /// Membuat kumpulan request notifikasi UNNotificationRequest secara deterministik
    public func buildNotificationRequests(
        todaySchedule: PrayerSchedule,
        tomorrowSchedule: PrayerSchedule?,
        preferences: [PrayerName: PrayerPreference],
        timeZone: TimeZone = .current,
        referenceDate: Date = Date()
    ) -> [UNNotificationRequest] {
        let now = referenceDate
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
        
        return pendingRequests
    }
    
    private func executeSchedule(
        revision: UInt64,
        todaySchedule: PrayerSchedule,
        tomorrowSchedule: PrayerSchedule?,
        preferences: [PrayerName: PrayerPreference],
        timeZone: TimeZone
    ) async {
        // Cek 1: Batalkan segera jika ada revisi yang lebih baru tiba saat mengantre
        guard !Task.isCancelled && revision == self.currentSchedulingRevision else {
            return
        }
        
        let pendingRequests = buildNotificationRequests(
            todaySchedule: todaySchedule,
            tomorrowSchedule: tomorrowSchedule,
            preferences: preferences,
            timeZone: timeZone
        )
        
        // Cek 2: Verifikasi kembali sebelum mengubah state NotificationCenter sistem
        guard !Task.isCancelled && revision == self.currentSchedulingRevision else {
            return
        }
        
        // Hapus pending lama secara bersih setelah batch sebelumnya dipastikan selesai
        await center.removeAllPendingNotificationRequests()
        
        // Daftarkan notifikasi baru dengan verifikasi revision dan error-handling eksplisit
        for req in pendingRequests {
            guard !Task.isCancelled && revision == self.currentSchedulingRevision else {
                return
            }
            do {
                try await center.add(req)
            } catch {
                let errorMsg = error.localizedDescription
                print("PrayerNotificationManager: Failed to add notification \(req.identifier) - \(errorMsg)")
                lastErrors.append((identifier: req.identifier, error: errorMsg))
            }
        }
    }
}
