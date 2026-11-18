import Foundation
import Combine
import AppKit

@MainActor
public final class PrayerScheduler: ObservableObject {
    public static let shared = PrayerScheduler()
    
    @Published public var schedule: PrayerSchedule?
    @Published public var tomorrowSchedule: PrayerSchedule?
    @Published public var nextPrayerName: PrayerName = .fajr
    @Published public var nextPrayerTime: Date = Date()
    @Published public var timeRemainingString: String = "--:--:--"
    @Published public var currentPrayerName: PrayerName?
    @Published public var missedPrayerAlert: String?
    
    private let calculator = PrayerCalculator()
    private var timer: Timer?
    private var lastCalculatedDay: Int = -1
    private var cancellables = Set<AnyCancellable>()
    private var lastTriggeredPrayerForAdhan: String?
    private var lastActiveTime: Date = Date()
    private var observerTokens: [NSObjectProtocol] = []
    
    public init() {
        setupSubscriptions()
        setupSystemNotifications()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }
    
    public func clearMissedPrayerAlert() {
        self.missedPrayerAlert = nil
    }
    
    private func setupSubscriptions() {
        // 1. Pantau perubahan lokasi
        LocationManager.shared.$latitude
            .combineLatest(LocationManager.shared.$longitude, LocationManager.shared.$currentTimeZone)
            .sink { [weak self] lat, lon, tz in
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
        // Observer 1: Tangani saat Mac bangun dari sleep
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
        
        // Observer 2: Tangani pergantian hari kalender sistem
        let dayChangedToken = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.lastCalculatedDay = -1
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
        }
        observerTokens.append(dayChangedToken)
        
        // Observer 3: Tangani jam sistem diubah secara manual atau sinkronisasi NTP
        let clockChangeToken = NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.lastCalculatedDay = -1
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
        }
        observerTokens.append(clockChangeToken)
    }
    
    /// Dipanggil saat Mac bangun dari sleep:
    /// - Menghindari pemutaran audio adzan yang mengejutkan secara retroaktif.
    /// - Mengidentifikasi apakah ada waktu shalat yang terlewati saat Mac dalam keadaan sleep.
    /// - Menampilkan notifikasi pemberitahuan sopan jika ada shalat yang terlewati.
    private func handleWakeFromSleep() {
        let now = Date()
        let sleepStartTime = lastActiveTime
        lastActiveTime = now
        
        if let currentSched = self.schedule {
            var missedPrayers: [PrayerName] = []
            let calendar = Calendar.current
            
            for prayer in PrayerName.fardhuPrayers {
                let prayerTime = currentSched.time(for: prayer)
                // Jika waktu shalat jatuh di rentang waktu Mac sedang tidur
                if prayerTime > sleepStartTime && prayerTime <= now {
                    missedPrayers.append(prayer)
                    // Tandai agar tidak memicu pemutaran audio adzan tiba-tiba
                    let comp = calendar.dateComponents([.year, .month, .day], from: prayerTime)
                    let triggerKey = "\(prayer.rawValue)-\(comp.year ?? 0)-\(comp.month ?? 0)-\(comp.day ?? 0)"
                    self.lastTriggeredPrayerForAdhan = triggerKey
                }
            }
            
            if let lastMissed = missedPrayers.last {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                formatter.timeZone = LocationManager.shared.currentTimeZone
                let timeStr = formatter.string(from: currentSched.time(for: lastMissed))
                self.missedPrayerAlert = "Waktu \(lastMissed.rawValue) telah masuk saat Mac berada dalam mode tidur (\(timeStr))."
            }
        }
        
        recalculate(
            latitude: LocationManager.shared.latitude,
            longitude: LocationManager.shared.longitude,
            timeZone: LocationManager.shared.currentTimeZone
        )
    }
    
    public func recalculate(latitude: Double, longitude: Double, timeZone: TimeZone) {
        var adjustments: [PrayerName: Int] = [:]
        let cityName = LocationManager.shared.locationName
        for name in PrayerName.allCases {
            let (adj, _) = PrayerSettings.shared.effectiveAdjustment(for: name, cityName: cityName)
            adjustments[name] = adj
        }
        
        let now = Date()
        
        // 1. Jadwal Hari Ini
        let todaySched = calculator.calculate(
            latitude: latitude,
            longitude: longitude,
            date: now,
            timeZone: timeZone,
            adjustments: adjustments
        )
        
        // 2. Jadwal Hari Besok (Dihitung astronomis independen tanpa konstanta 86400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let tomorrowDate: Date
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: now) {
            tomorrowDate = nextDay
        } else {
            var comp = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
            comp.day = (comp.day ?? 1) + 1
            tomorrowDate = calendar.date(from: comp) ?? now
        }
        
        let tomorrowSched = calculator.calculate(
            latitude: latitude,
            longitude: longitude,
            date: tomorrowDate,
            timeZone: timeZone,
            adjustments: adjustments
        )
        
        self.schedule = todaySched
        self.tomorrowSchedule = tomorrowSched
        
        updateNextPrayer()
        
        // 3. Jadwalkan notifikasi sistem macOS
        if let sched = todaySched {
            let prefs = PrayerSettings.shared.preferences
            Task {
                await PrayerNotificationManager.shared.scheduleAll(
                    todaySchedule: sched,
                    tomorrowSchedule: tomorrowSched,
                    preferences: prefs
                )
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        // Timer 1 detik untuk countdown dan update waktu aktif
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        let now = Date()
        lastActiveTime = now
        
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: now)
        
        // Cek pergantian hari (midnight rollover)
        if lastCalculatedDay != -1 && currentDay != lastCalculatedDay {
            lastCalculatedDay = currentDay
            recalculate(
                latitude: LocationManager.shared.latitude,
                longitude: LocationManager.shared.longitude,
                timeZone: LocationManager.shared.currentTimeZone
            )
            return
        }
        lastCalculatedDay = currentDay
        
        updateNextPrayer()
        checkAdhanTrigger(now: now)
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
    /// Hanya memicu jika berada dalam jendela toleransi [0 ..< 45 detik] dari waktu masuk shalat.
    private func checkAdhanTrigger(now: Date) {
        guard let schedule = schedule else { return }
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        for prayer in PrayerName.fardhuPrayers {
            let pref = PrayerSettings.shared.preferences[prayer] ?? PrayerPreference()
            guard pref.enabled && pref.adhanEnabled else { continue }
            
            let prayerDate = schedule.time(for: prayer)
            let diffSeconds = now.timeIntervalSince(prayerDate)
            
            // Hanya aktifkan jika masuk tepat di menit shalat (selisih antara 0 hingga 45 detik)
            guard diffSeconds >= 0 && diffSeconds < 45 else { continue }
            
            let prayerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            
            if nowComponents.year == prayerComponents.year &&
               nowComponents.month == prayerComponents.month &&
               nowComponents.day == prayerComponents.day &&
               nowComponents.hour == prayerComponents.hour &&
               nowComponents.minute == prayerComponents.minute {
                
                let triggerKey = "\(prayer.rawValue)-\(nowComponents.year ?? 0)-\(nowComponents.month ?? 0)-\(nowComponents.day ?? 0)"
                if lastTriggeredPrayerForAdhan != triggerKey {
                    lastTriggeredPrayerForAdhan = triggerKey
                    AdhanAudioManager.shared.play(for: prayer)
                }
            }
        }
    }
}
