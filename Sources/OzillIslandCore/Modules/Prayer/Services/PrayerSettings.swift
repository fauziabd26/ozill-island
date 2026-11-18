import Foundation
import Combine

public struct PrayerPreference: Codable, Equatable {
    public var enabled: Bool
    public var reminderMinutes: Int
    public var adhanEnabled: Bool
    public var adjustmentMinutes: Int // Koreksi manual / ihtiyati (-5 s/d +5)
    
    public init(
        enabled: Bool = true,
        reminderMinutes: Int = 10,
        adhanEnabled: Bool = false,
        adjustmentMinutes: Int = 2
    ) {
        self.enabled = enabled
        self.reminderMinutes = reminderMinutes
        self.adhanEnabled = adhanEnabled
        self.adjustmentMinutes = adjustmentMinutes
    }
}

public enum LocationMode: String, Codable {
    case automaticGPS
    case manualPreset
}

@MainActor
public final class PrayerSettings: ObservableObject {
    public static let shared = PrayerSettings()
    
    private let preferencesKey = "OzillIsland_PrayerPreferences"
    private let locationModeKey = "OzillIsland_LocationMode"
    private let selectedCityKey = "OzillIsland_SelectedCity"
    
    @Published public var preferences: [PrayerName: PrayerPreference] {
        didSet {
            savePreferences()
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
        // Load Location Mode
        if let modeRaw = UserDefaults.standard.string(forKey: locationModeKey),
           let mode = LocationMode(rawValue: modeRaw) {
            self.locationMode = mode
        } else {
            self.locationMode = .automaticGPS
        }
        
        // Load Selected City
        if let cityData = UserDefaults.standard.data(forKey: selectedCityKey),
           let city = try? JSONDecoder().decode(CityPreset.self, from: cityData) {
            self.selectedCity = city
        } else {
            self.selectedCity = CityPreset.defaultCity
        }
        
        // Load Preferences
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
                .sunrise: PrayerPreference(enabled: false, reminderMinutes: 0, adhanEnabled: false, adjustmentMinutes: 0),
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
            return PrayerPreference(enabled: true, reminderMinutes: 15, adhanEnabled: true, adjustmentMinutes: 2)
        case .sunrise:
            return PrayerPreference(enabled: false, reminderMinutes: 0, adhanEnabled: false, adjustmentMinutes: 0)
        case .dhuhr:
            return PrayerPreference(enabled: true, reminderMinutes: 10, adhanEnabled: true, adjustmentMinutes: 2)
        case .asr:
            return PrayerPreference(enabled: true, reminderMinutes: 10, adhanEnabled: false, adjustmentMinutes: 2)
        case .maghrib:
            return PrayerPreference(enabled: true, reminderMinutes: 15, adhanEnabled: true, adjustmentMinutes: 2)
        case .isha:
            return PrayerPreference(enabled: true, reminderMinutes: 10, adhanEnabled: true, adjustmentMinutes: 2)
        }
    }
    
    public func update(
        _ prayer: PrayerName,
        enabled: Bool? = nil,
        reminderMinutes: Int? = nil,
        adhanEnabled: Bool? = nil,
        adjustmentMinutes: Int? = nil
    ) {
        var current = preferences[prayer] ?? PrayerSettings.defaultPreference(for: prayer)
        if let enabled = enabled { current.enabled = enabled }
        if let reminderMinutes = reminderMinutes { current.reminderMinutes = reminderMinutes }
        if let adhanEnabled = adhanEnabled { current.adhanEnabled = adhanEnabled }
        if let adjustmentMinutes = adjustmentMinutes {
            // Batasi -5 s/d +5 menit sesuai acceptance criteria
            current.adjustmentMinutes = max(-5, min(5, adjustmentMinutes))
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
