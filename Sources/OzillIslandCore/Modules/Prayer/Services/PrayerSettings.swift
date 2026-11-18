import Foundation
import Combine

public enum IhtiyatiPolicy: String, CaseIterable, Identifiable, Codable {
    case none = "Tanpa Ihtiyati (Astronomis Murni)"
    case kemenag = "Rekomendasi Kemenag RI (Kalibrasi SIHAT)"
    case custom = "Koreksi Manual Kustom"
    
    public var id: String { rawValue }
    
    public func baseBuffer(for prayer: PrayerName) -> Int {
        switch self {
        case .none, .custom:
            return 0
        case .kemenag:
            // Berdasarkan audit komparatif terhadap SIHAT Bimas Islam Kemenag RI:
            // Subuh & Isya menggunakan buffer +2 menit, Dzuhur, Ashar, Maghrib menggunakan buffer +3 menit.
            // Syuruq (terbit) tidak ditambah buffer (0 menit).
            switch prayer {
            case .fajr: return 2
            case .sunrise: return 0
            case .dhuhr: return 3
            case .asr: return 3
            case .maghrib: return 3
            case .isha: return 2
            }
        }
    }
}

public struct PrayerPreference: Codable, Equatable {
    public var enabled: Bool
    public var reminderMinutes: Int
    public var adhanEnabled: Bool
    public var manualAdjustmentMinutes: Int // Koreksi pengguna (-5 s/d +5)
    
    public init(
        enabled: Bool = true,
        reminderMinutes: Int = 10,
        adhanEnabled: Bool = false,
        manualAdjustmentMinutes: Int = 0
    ) {
        self.enabled = enabled
        self.reminderMinutes = reminderMinutes
        self.adhanEnabled = adhanEnabled
        self.manualAdjustmentMinutes = manualAdjustmentMinutes
    }
}

public enum LocationMode: String, Codable {
    case automaticGPS
    case manualPreset
}

@MainActor
public final class PrayerSettings: ObservableObject {
    public static let shared = PrayerSettings()
    
    private let preferencesKey = "OzillIsland_PrayerPreferences_v2"
    private let locationModeKey = "OzillIsland_LocationMode"
    private let selectedCityKey = "OzillIsland_SelectedCity"
    private let ihtiyatiPolicyKey = "OzillIsland_IhtiyatiPolicy"
    
    @Published public var preferences: [PrayerName: PrayerPreference] {
        didSet {
            savePreferences()
        }
    }
    
    @Published public var ihtiyatiPolicy: IhtiyatiPolicy {
        didSet {
            UserDefaults.standard.set(ihtiyatiPolicy.rawValue, forKey: ihtiyatiPolicyKey)
        }
    }
    
    @Published public var locationMode: LocationMode {
        didSet {
            UserDefaults.standard.set(locationMode.rawValue, forKey: locationModeKey)
        }
    }
    
    @Published public var selectedCity: CityPreset {
        didSet {
            if let encoded = try? JSONEncoder().encode(selectedCity) {
                UserDefaults.standard.set(encoded, forKey: selectedCityKey)
            }
        }
    }
    
    public init() {
        // 1. Load Location Mode
        if let modeRaw = UserDefaults.standard.string(forKey: locationModeKey),
           let mode = LocationMode(rawValue: modeRaw) {
            self.locationMode = mode
        } else {
            self.locationMode = .automaticGPS
        }
        
        // 2. Load Selected City
        if let cityData = UserDefaults.standard.data(forKey: selectedCityKey),
           let city = try? JSONDecoder().decode(CityPreset.self, from: cityData) {
            self.selectedCity = city
        } else {
            self.selectedCity = CityPreset.defaultCity
        }
        
        // 3. Load Ihtiyati Policy (Default: .kemenag)
        if let policyRaw = UserDefaults.standard.string(forKey: ihtiyatiPolicyKey),
           let policy = IhtiyatiPolicy(rawValue: policyRaw) {
            self.ihtiyatiPolicy = policy
        } else {
            self.ihtiyatiPolicy = .kemenag
        }
        
        // 4. Load Preferences (Default: manualAdjustmentMinutes = 0)
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let saved = try? JSONDecoder().decode([String: PrayerPreference].self, from: data) {
            var loaded: [PrayerName: PrayerPreference] = [:]
            for prayer in PrayerName.allCases {
                if let pref = saved[prayer.rawValue] {
                    loaded[prayer] = pref
                } else {
                    loaded[prayer] = PrayerSettings.defaultPreference(for: prayer)
                }
            }
            self.preferences = loaded
        } else {
            self.preferences = [
                .fajr: PrayerSettings.defaultPreference(for: .fajr),
                .sunrise: PrayerPreference(enabled: false, reminderMinutes: 0, adhanEnabled: false, manualAdjustmentMinutes: 0),
                .dhuhr: PrayerSettings.defaultPreference(for: .dhuhr),
                .asr: PrayerSettings.defaultPreference(for: .asr),
                .maghrib: PrayerSettings.defaultPreference(for: .maghrib),
                .isha: PrayerSettings.defaultPreference(for: .isha)
            ]
        }
    }
    
    private static func defaultPreference(for prayer: PrayerName) -> PrayerPreference {
        switch prayer {
        case .fajr:
            return PrayerPreference(enabled: true, reminderMinutes: 15, adhanEnabled: true, manualAdjustmentMinutes: 0)
        case .sunrise:
            return PrayerPreference(enabled: false, reminderMinutes: 0, adhanEnabled: false, manualAdjustmentMinutes: 0)
        case .dhuhr:
            return PrayerPreference(enabled: true, reminderMinutes: 10, adhanEnabled: true, manualAdjustmentMinutes: 0)
        case .asr:
            return PrayerPreference(enabled: true, reminderMinutes: 10, adhanEnabled: false, manualAdjustmentMinutes: 0)
        case .maghrib:
            return PrayerPreference(enabled: true, reminderMinutes: 15, adhanEnabled: true, manualAdjustmentMinutes: 0)
        case .isha:
            return PrayerPreference(enabled: true, reminderMinutes: 10, adhanEnabled: true, manualAdjustmentMinutes: 0)
        }
    }
    
    /// Menghitung penyesuaian efektif total (Base Buffer Kebijakan + Koreksi Manual Pengguna)
    public func effectiveAdjustment(for prayer: PrayerName) -> Int {
        let base = ihtiyatiPolicy.baseBuffer(for: prayer)
        let manual = preferences[prayer]?.manualAdjustmentMinutes ?? 0
        return base + manual
    }
    
    public func update(
        _ prayer: PrayerName,
        enabled: Bool? = nil,
        reminderMinutes: Int? = nil,
        adhanEnabled: Bool? = nil,
        manualAdjustmentMinutes: Int? = nil
    ) {
        var current = preferences[prayer] ?? PrayerSettings.defaultPreference(for: prayer)
        if let enabled = enabled { current.enabled = enabled }
        if let reminderMinutes = reminderMinutes { current.reminderMinutes = reminderMinutes }
        if let adhanEnabled = adhanEnabled { current.adhanEnabled = adhanEnabled }
        if let manualAdjustmentMinutes = manualAdjustmentMinutes {
            // Batasi koreksi manual -5 s/d +5 menit
            current.manualAdjustmentMinutes = max(-5, min(5, manualAdjustmentMinutes))
        }
        preferences[prayer] = current
    }
    
    private func savePreferences() {
        var toSave: [String: PrayerPreference] = [:]
        for (k, v) in preferences {
            toSave[k.rawValue] = v
        }
        if let encoded = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }
    }
}
