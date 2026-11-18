import Foundation
import Combine

public enum IhtiyatiPolicy: String, CaseIterable, Identifiable, Codable {
    case pureAstronomical = "Astronomis Murni (Offset 0)"
    case sihatReference = "Kalibrasi Referensi SIHAT (Terverifikasi)"
    case custom = "Koreksi Manual Pengguna"
    
    public var id: String { rawValue }
    
    /// Memberikan base buffer menit berdasarkan kebijakan dan kota tertentu.
    /// Tidak mengasumsikan seluruh kota di Indonesia memiliki buffer identik.
    public func baseBuffer(for prayer: PrayerName, cityName: String) -> (buffer: Int, isCalibrated: Bool) {
        switch self {
        case .pureAstronomical:
            return (0, true)
            
        case .custom:
            return (0, true)
            
        case .sihatReference:
            // Kalibrasi referensi spesifik berdasarkan snapshot resmi SIHAT Bimas Islam Kemenag RI
            if cityName.contains("Jakarta") {
                switch prayer {
                case .fajr: return (2, true)
                case .sunrise: return (0, true)
                case .dhuhr: return (3, true)
                case .asr: return (3, true)
                case .maghrib: return (3, true)
                case .isha: return (2, true)
                }
            } else if cityName.contains("Surabaya") {
                switch prayer {
                case .fajr: return (3, true)
                case .sunrise: return (-3, true)
                case .dhuhr: return (4, true)
                case .asr: return (3, true)
                case .maghrib: return (3, true)
                case .isha: return (3, true)
                }
            } else {
                // Untuk kota yang belum memiliki kalibrasi referensi khusus, fallback ke 0 (murni astronomis)
                // dan tandai bahwa kalibrasi khusus kota ini belum tersedia.
                return (0, false)
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
    
    private let preferencesKey = "OzillIsland_PrayerPreferences_v3"
    private let locationModeKey = "OzillIsland_LocationMode_v3"
    private let selectedCityKey = "OzillIsland_SelectedCity_v3"
    private let ihtiyatiPolicyKey = "OzillIsland_IhtiyatiPolicy_v3"
    
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
        
        // 3. Load Ihtiyati Policy (Default: .pureAstronomical untuk kejujuran ilmiah baseline)
        if let policyRaw = UserDefaults.standard.string(forKey: ihtiyatiPolicyKey),
           let policy = IhtiyatiPolicy(rawValue: policyRaw) {
            self.ihtiyatiPolicy = policy
        } else {
            self.ihtiyatiPolicy = .pureAstronomical
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
    
    /// Menghitung penyesuaian efektif total dengan semantik yang jelas:
    /// - Jika mode .pureAstronomical: penyesuaian SELALU 0 (koreksi manual diabaikan demi integritas mode falak murni).
    /// - Jika mode .sihatReference: baseBuffer kota terkait + manualAdjustmentMinutes.
    /// - Jika mode .custom: murni manualAdjustmentMinutes.
    public func effectiveAdjustment(for prayer: PrayerName, cityName: String) -> (totalMinutes: Int, isCalibrated: Bool) {
        switch ihtiyatiPolicy {
        case .pureAstronomical:
            return (0, true)
            
        case .custom:
            let manual = preferences[prayer]?.manualAdjustmentMinutes ?? 0
            return (manual, true)
            
        case .sihatReference:
            let (base, calibrated) = ihtiyatiPolicy.baseBuffer(for: prayer, cityName: cityName)
            let manual = preferences[prayer]?.manualAdjustmentMinutes ?? 0
            return (base + manual, calibrated)
        }
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
