import Foundation
import Combine
import AppKit

public struct MissedPrayerOccurrence: Equatable {
    public let prayer: PrayerName
    public let time: Date
    
    public init(prayer: PrayerName, time: Date) {
        self.prayer = prayer
        self.time = time
    }
}

@MainActor
public final class PrayerScheduler: ObservableObject {
    public static let shared = PrayerScheduler()
    
    // MARK: - Named Constants
    public static let maxSleepDurationToAnalyze: TimeInterval = 24 * 60 * 60 // 24 Jam
    public static let minSleepDurationToAnalyze: TimeInterval = 15 // 15 Detik
    public static let adhanOnsetToleranceWindow: TimeInterval = 45 // 45 Detik
    
    @Published public var schedule: PrayerSchedule?
    @Published public var tomorrowSchedule: PrayerSchedule?
    @Published public var nextPrayerName: PrayerName = .fajr
    @Published public var nextPrayerTime: Date = Date()
    @Published public var timeRemainingString: String = "--:--:--"
    @Published public var currentPrayerName: PrayerName?
    @Published public var missedPrayerAlert: String?
    
    private let calculator = PrayerCalculator()
    private var timer: Timer?
    private var lastCalculatedDateComponents: DateComponents?
    private var cancellables = Set<AnyCancellable>()
    private var triggeredPrayerKeys = Set<String>()
    private var lastActiveTime: Date = Date()
    private var recordedSleepTime: Date?
    private var isInitialLaunch: Bool = true
    private var observerTokens: [NSObjectProtocol] = []
    private var notificationTask: Task<Void, Never>?
    
    public init() {
        setupSubscriptions()
        setupSystemNotifications()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
        notificationTask?.cancel()
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }
    
    public func clearMissedPrayerAlert() {
        self.missedPrayerAlert = nil
    }
    
    private func setupSubscriptions() {
        // 1. Pantau perubahan lokasi dan timezone
        LocationManager.shared.$latitude
            .combineLatest(LocationManager.shared.$longitude, LocationManager.shared.$currentTimeZone)
            .sink { [weak self] lat, lon, tz in
                self?.lastCalculatedDateComponents = nil
                self?.recalculate(latitude: lat, longitude: lon, timeZone: tz)
            }
            .store(in: &cancellables)
        
        // 2. Pantau perubahan preferensi & kebijakan ihtiyati pengguna
        PrayerSettings.shared.$preferences
            .combineLatest(PrayerSettings.shared.$ihtiyatiPolicy)
            .sink { [weak self] _, _ in
                guard let self = self else { return }
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
            .store(in: &cancellables)
    }
    
    private func setupSystemNotifications() {
        // Observer 1: Tangkap timestamp tepat sebelum Mac tidur (menghindari race condition dengan timer tick saat bangun)
        let willSleepToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordedSleepTime = Date()
            }
        }
        observerTokens.append(willSleepToken)
        
        // Observer 2: Tangani saat Mac bangun dari sleep
        let wakeToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWakeFromSleep()
            }
        }
        observerTokens.append(wakeToken)
        
        // Observer 3: Tangani pergantian hari kalender sistem
        let dayChangedToken = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.lastCalculatedDateComponents = nil
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
        }
        observerTokens.append(dayChangedToken)
        
        // Observer 4: Tangani jam sistem diubah secara manual atau sinkronisasi NTP
        let clockChangeToken = NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.lastCalculatedDateComponents = nil
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
        }
        observerTokens.append(clockChangeToken)
    }
    
    /// Menangani peristiwa saat Mac bangun dari sleep:
    /// - Menggunakan recordedSleepTime (dari willSleepNotification) untuk keandalan anti-race-condition dengan timer tick.
    /// - Mengaudit rentang sleep bahkan jika melintasi tengah malam.
    /// - Mencegah pemutaran audio adzan secara retroaktif untuk shalat yang telah lewat.
    /// - Mencegah false banner saat aplikasi baru pertama kali dijalankan.
    /// - Menerapkan kebijakan sopan jika Mac tidur lebih dari 24 jam.
    public func handleWakeFromSleep() {
        let now = Date()
        // Prioritaskan timestamp presisi yang ditangkap sebelum sleep
        let sleepStartTime = recordedSleepTime ?? lastActiveTime
        recordedSleepTime = nil
        lastActiveTime = now
        
        // Abaikan jika initial launch atau jam sistem mundur
        guard !isInitialLaunch, sleepStartTime <= now else {
            isInitialLaunch = false
            recalculate(
                latitude: LocationManager.shared.latitude,
                longitude: LocationManager.shared.longitude,
                timeZone: LocationManager.shared.currentTimeZone
            )
            return
        }
        
        let elapsed = now.timeIntervalSince(sleepStartTime)
        // Jika sleep sangat singkat di bawah ambang batas, tidak perlu analisis missed prayer
        guard elapsed >= Self.minSleepDurationToAnalyze else {
            recalculate(
                latitude: LocationManager.shared.latitude,
                longitude: LocationManager.shared.longitude,
                timeZone: LocationManager.shared.currentTimeZone
            )
            return
        }
        
        let tz = LocationManager.shared.currentTimeZone
        let lat = LocationManager.shared.latitude
        let lon = LocationManager.shared.longitude
        let cityName = LocationManager.shared.locationName
        
        // Kebijakan Durasi Tidur > 24 Jam (Multi-day sleep)
        if elapsed > Self.maxSleepDurationToAnalyze {
            self.missedPrayerAlert = "Mac berada dalam mode tidur lebih dari 24 jam. Jadwal shalat telah diperbarui secara otomatis."
            // Blacklist seluruh waktu shalat hari ini yang sudah lewat agar tidak memicu adzan
            recalculate(latitude: lat, longitude: lon, timeZone: tz)
            if let current = self.schedule {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = tz
                for prayer in PrayerName.fardhuPrayers {
                    let pTime = current.time(for: prayer)
                    if pTime <= now {
                        let comp = cal.dateComponents([.year, .month, .day], from: pTime)
                        let triggerKey = "\(prayer.rawValue)-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
                        self.triggeredPrayerKeys.insert(triggerKey)
                    }
                }
            }
            return
        }
        
        // Durasi tidur <= 24 Jam: Periksa hari-hari yang dilintasi antara sleepStartTime dan now
        var missedOccurrences: [MissedPrayerOccurrence] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        
        // Kumpulkan tanggal-tanggal unik yang dilintasi
        var checkDates: [Date] = [sleepStartTime]
        let startDay = cal.startOfDay(for: sleepStartTime)
        let endDay = cal.startOfDay(for: now)
        if startDay != endDay {
            checkDates.append(now)
        }
        
        for d in checkDates {
            var adjustments: [PrayerName: Int] = [:]
            for name in PrayerName.allCases {
                let (adj, _, _) = PrayerSettings.shared.effectiveAdjustment(for: name, cityName: cityName, date: d, timeZone: tz)
                adjustments[name] = adj
            }
            
            if let sched = calculator.calculate(latitude: lat, longitude: lon, date: d, timeZone: tz, adjustments: adjustments) {
                for prayer in PrayerName.fardhuPrayers {
                    let pTime = sched.time(for: prayer)
                    if pTime > sleepStartTime && pTime <= now {
                        missedOccurrences.append(MissedPrayerOccurrence(prayer: prayer, time: pTime))
                        // Blacklist secara ketat dari pemicu adzan retroaktif
                        let comp = cal.dateComponents([.year, .month, .day], from: pTime)
                        let triggerKey = "\(prayer.rawValue)-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
                        self.triggeredPrayerKeys.insert(triggerKey)
                    }
                }
            }
        }
        
        if !missedOccurrences.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = tz
            let tzAbbr = tz.indonesianAbbreviation
            
            let parts = missedOccurrences.map { occ in
                "\(occ.prayer.rawValue) (\(formatter.string(from: occ.time)))"
            }.joined(separator: ", ")
            
            let tzSuffix = tzAbbr.isEmpty ? "" : " \(tzAbbr)"
            self.missedPrayerAlert = "Waktu \(parts)\(tzSuffix) telah masuk saat Mac berada dalam mode tidur."
        }
        
        recalculate(latitude: lat, longitude: lon, timeZone: tz)
    }
    
    public func recalculate(latitude: Double, longitude: Double, timeZone: TimeZone) {
        let cityName = LocationManager.shared.locationName
        let now = Date()
        
        // 1. Penyesuaian Hari Ini
        var todayAdjustments: [PrayerName: Int] = [:]
        for name in PrayerName.allCases {
            let (adj, _, _) = PrayerSettings.shared.effectiveAdjustment(for: name, cityName: cityName, date: now, timeZone: timeZone)
            todayAdjustments[name] = adj
        }
        
        let todaySched = calculator.calculate(
            latitude: latitude,
            longitude: longitude,
            date: now,
            timeZone: timeZone,
            adjustments: todayAdjustments
        )
        
        // 2. Penyesuaian Hari Besok
        // Bersih dari magic numbers dan fallback now:
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) else {
            assertionFailure("Fatal: Gagal menghitung tomorrowDate dari \(now) dengan timezone \(timeZone.identifier)")
            return
        }
        
        var tomorrowAdjustments: [PrayerName: Int] = [:]
        for name in PrayerName.allCases {
            let (adj, _, _) = PrayerSettings.shared.effectiveAdjustment(for: name, cityName: cityName, date: tomorrowDate, timeZone: timeZone)
            tomorrowAdjustments[name] = adj
        }
        
        let tomorrowSched = calculator.calculate(
            latitude: latitude,
            longitude: longitude,
            date: tomorrowDate,
            timeZone: timeZone,
            adjustments: tomorrowAdjustments
        )
        
        self.schedule = todaySched
        self.tomorrowSchedule = tomorrowSched
        
        updateNextPrayer()
        
        // 3. Jadwalkan notifikasi sistem macOS dengan pembatalan task aktif sebelumnya
        if let sched = todaySched {
            let prefs = PrayerSettings.shared.preferences
            notificationTask?.cancel()
            notificationTask = Task {
                await PrayerNotificationManager.shared.scheduleAll(
                    todaySchedule: sched,
                    tomorrowSchedule: tomorrowSched,
                    preferences: prefs,
                    timeZone: timeZone
                )
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        // Timer 1 detik untuk countdown yang presisi dan deteksi trigger adzan
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        let now = Date()
        lastActiveTime = now
        isInitialLaunch = false
        
        let tz = LocationManager.shared.currentTimeZone
        var locationCalendar = Calendar(identifier: .gregorian)
        locationCalendar.timeZone = tz
        let currentDayComponents = locationCalendar.dateComponents([.year, .month, .day], from: now)
        
        // Deteksi pergantian hari kalender di timezone lokasi shalat (bukan hanya jam Mac lokal)
        if let last = lastCalculatedDateComponents, last != currentDayComponents {
            lastCalculatedDateComponents = currentDayComponents
            pruneTriggeredPrayerKeys(currentDate: now, timeZone: tz)
            recalculate(
                latitude: LocationManager.shared.latitude,
                longitude: LocationManager.shared.longitude,
                timeZone: tz
            )
            return
        }
        lastCalculatedDateComponents = currentDayComponents
        
        updateNextPrayer()
        checkAdhanTrigger(now: now)
    }
    
    /// Membersihkan kunci adzan lama agar memori Set<String> tidak bertumbuh tanpa batas
    private func pruneTriggeredPrayerKeys(currentDate: Date, timeZone: TimeZone) {
        guard triggeredPrayerKeys.count > 20 else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        
        // Hanya pertahankan key untuk 3 hari: kemarin, hari ini, dan besok
        var allowedDateStrings = Set<String>()
        for offset in -1...1 {
            if let d = cal.date(byAdding: .day, value: offset, to: currentDate) {
                let comp = cal.dateComponents([.year, .month, .day], from: d)
                allowedDateStrings.insert("\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)")
            }
        }
        
        triggeredPrayerKeys = triggeredPrayerKeys.filter { key in
            allowedDateStrings.contains { dateStr in key.hasSuffix(dateStr) }
        }
    }
    
    private func updateNextPrayer() {
        guard let schedule = schedule else { return }
        let now = Date()
        
        let next = schedule.nextPrayer(from: now, tomorrowSchedule: tomorrowSchedule)
        self.nextPrayerName = next.prayer
        self.nextPrayerTime = next.time
        
        self.currentPrayerName = schedule.currentPrayer(from: now)?.prayer
        
        let diff = max(0, Int(next.time.timeIntervalSince(now)))
        let hours = diff / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60
        
        if hours > 0 {
            self.timeRemainingString = String(format: "-%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            self.timeRemainingString = String(format: "-%02d:%02d", minutes, seconds)
        }
    }
    
    /// Mengecek apakah detik ini tepat masuk waktu shalat untuk memutar adzan jika diaktifkan.
    /// Menggunakan Set<String> deduplication dan toleransi jendela onset ketat.
    private func checkAdhanTrigger(now: Date) {
        guard let schedule = schedule else { return }
        let tz = LocationManager.shared.currentTimeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        for prayer in PrayerName.fardhuPrayers {
            let pref = PrayerSettings.shared.preferences[prayer] ?? PrayerPreference()
            guard pref.enabled && pref.adhanEnabled else { continue }
            
            let prayerDate = schedule.time(for: prayer)
            let diffSeconds = now.timeIntervalSince(prayerDate)
            
            // Hanya aktifkan jika masuk tepat di menit shalat (selisih antara 0 hingga ambang batas toleransi)
            guard diffSeconds >= 0 && diffSeconds < Self.adhanOnsetToleranceWindow else { continue }
            
            let prayerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            
            if nowComponents.year == prayerComponents.year &&
               nowComponents.month == prayerComponents.month &&
               nowComponents.day == prayerComponents.day &&
               nowComponents.hour == prayerComponents.hour &&
               nowComponents.minute == prayerComponents.minute {
                
                let triggerKey = "\(prayer.rawValue)-\(nowComponents.year ?? 0)-\(nowComponents.month ?? 0)-\(nowComponents.day ?? 0)"
                if !triggeredPrayerKeys.contains(triggerKey) {
                    triggeredPrayerKeys.insert(triggerKey)
                    AdhanAudioManager.shared.play(for: prayer)
                }
            }
        }
    }
}
