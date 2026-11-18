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
    
    private let calculator = PrayerCalculator()
    private var timer: Timer?
    private var lastCalculatedDay: Int = -1
    private var cancellables = Set<AnyCancellable>()
    private var lastTriggeredPrayerForAdhan: String?
    
    public init() {
        setupSubscriptions()
        setupSystemNotifications()
        startTimer()
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
        // Tangani saat Mac bangun dari sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
        }
        
        // Tangani saat ada pergantian hari kalender atau jam sistem diubah
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recalculate(
                    latitude: LocationManager.shared.latitude,
                    longitude: LocationManager.shared.longitude,
                    timeZone: LocationManager.shared.currentTimeZone
                )
            }
        }
    }
    
    public func recalculate(latitude: Double, longitude: Double, timeZone: TimeZone) {
        var adjustments: [PrayerName: Int] = [:]
        for name in PrayerName.allCases {
            adjustments[name] = PrayerSettings.shared.effectiveAdjustment(for: name)
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
        
        // 2. Jadwal Hari Besok (Dihitung astronomis independen untuk akurasi Subuh besok)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        
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
        // Timer 1 detik untuk countdown yang presisi dan deteksi masuk waktu shalat
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        let now = Date()
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
    
    /// Mengecek apakah detik ini tepat masuk waktu shalat untuk memutar adzan jika diaktifkan
    private func checkAdhanTrigger(now: Date) {
        guard let schedule = schedule else { return }
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        for prayer in PrayerName.fardhuPrayers {
            let pref = PrayerSettings.shared.preferences[prayer] ?? PrayerPreference()
            guard pref.enabled && pref.adhanEnabled else { continue }
            
            let prayerDate = schedule.time(for: prayer)
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
