import Foundation
import SwiftUI
import Combine
import IOKit.ps

/// Layanan sistem terpusat untuk membaca waktu realtime, kalender Masehi & Hijriah, serta status baterai macOS.
@MainActor
public final class SystemInfoService: ObservableObject {
    public static let shared = SystemInfoService()
    
    @Published public private(set) var currentDateMasehi: String = ""
    @Published public private(set) var shortDateMasehi: String = ""
    @Published public private(set) var currentDateHijri: String = ""
    @Published public private(set) var currentTimeString: String = ""
    @Published public private(set) var currentSecondsString: String = ""
    
    @Published public private(set) var batteryLevel: Int = 100
    @Published public private(set) var isBatteryCharging: Bool = false
    @Published public private(set) var isACPluggedIn: Bool = true
    @Published public private(set) var showChargerConnectedBanner: Bool = false
    @Published public private(set) var isLowBatteryAlert: Bool = false
    
    private var previousACPluggedIn: Bool?
    private var bannerDismissTask: Task<Void, Never>?
    
    private var timer: Timer?
    private let masehiFormatter: DateFormatter
    private let shortFormatter: DateFormatter
    private let hijriFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let secondsFormatter: DateFormatter
    
    public init() {
        let localeID = Locale(identifier: "id_ID")
        
        let mf = DateFormatter()
        mf.locale = localeID
        mf.dateFormat = "EEEE, d MMMM yyyy"
        self.masehiFormatter = mf
        
        let sf = DateFormatter()
        sf.locale = localeID
        sf.dateFormat = "EEE, d MMM"
        self.shortFormatter = sf
        
        let hf = DateFormatter()
        hf.calendar = Calendar(identifier: .islamicCivil)
        hf.locale = localeID
        hf.dateFormat = "d MMMM yyyy"
        self.hijriFormatter = hf
        
        let tf = DateFormatter()
        tf.locale = localeID
        tf.dateFormat = "HH:mm"
        self.timeFormatter = tf
        
        let secF = DateFormatter()
        secF.locale = localeID
        secF.dateFormat = "ss"
        self.secondsFormatter = secF
        
        updateSystemInfo()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    public func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSystemInfo()
            }
        }
    }
    
    public func updateSystemInfo() {
        let now = Date()
        self.currentDateMasehi = masehiFormatter.string(from: now)
        self.shortDateMasehi = shortFormatter.string(from: now)
        self.currentDateHijri = "\(hijriFormatter.string(from: now)) H"
        self.currentTimeString = timeFormatter.string(from: now)
        self.currentSecondsString = secondsFormatter.string(from: now)
        
        updateBatteryInfo()
    }
    
    private func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let max = desc[kIOPSMaxCapacityKey as String] as? Int {
                let newLevel = max > 0 ? Int((Double(current) / Double(max)) * 100) : current
                let newCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
                let pState = (desc[kIOPSPowerSourceStateKey as String] as? String) ?? ""
                let newAC = (pState == (kIOPSACPowerValue as String))
                
                let wasAC = self.previousACPluggedIn
                
                self.batteryLevel = newLevel
                self.isBatteryCharging = newCharging
                self.isACPluggedIn = newAC
                
                // Pop-up animasi saat charger disambungkan
                if let prev = wasAC, !prev && newAC {
                    triggerChargerBanner()
                }
                self.previousACPluggedIn = newAC
                
                // Peringatan baterai lemah <= 15% jika tidak sedang dicas
                self.isLowBatteryAlert = (newLevel <= 15 && !newAC)
                break
            }
        }
    }
    
    /// Memicu pop-up animasi pengisian daya selama 3.5 detik
    public func triggerChargerBanner() {
        bannerDismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.showChargerConnectedBanner = true
        }
        bannerDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 detik
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.showChargerConnectedBanner = false
                }
            }
        }
    }
    
    public var batteryIcon: String {
        if isBatteryCharging {
            return "battery.100.bolt"
        }
        switch batteryLevel {
        case 0..<20: return "battery.0"
        case 20..<50: return "battery.25"
        case 50..<80: return "battery.50"
        case 80..<95: return "battery.75"
        default: return "battery.100"
        }
    }
}
