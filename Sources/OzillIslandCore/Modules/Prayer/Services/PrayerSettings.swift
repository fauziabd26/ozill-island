import Foundation
import Combine

// MARK: - Model Snapshot Resmi SIHAT Kemenag RI
/// Merepresentasikan data snapshot empiris resmi yang diambil dari SIHAT Bimas Islam Kemenag RI.
/// Setiap snapshot memiliki identitas lengkap untuk menjamin integritas data (tidak digeneralisasi untuk tanggal lain).
public struct SihatOfficialSnapshot: Codable, Equatable {
    public let regionName: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    public let targetDateString: String // Format: YYYY-MM-DD
    public let referenceUrl: String
    public let retrievedAt: String // ISO 8601
    public let officialTimes: [PrayerName: String] // HH:mm
    public let empiricalOffsets: [PrayerName: Int] // Menit selisih vs Hisab Falak Mentah
    
    public init(
        regionName: String,
        latitude: Double,
        longitude: Double,
        timeZoneIdentifier: String,
        targetDateString: String,
        referenceUrl: String,
        retrievedAt: String,
        officialTimes: [PrayerName: String],
        empiricalOffsets: [PrayerName: Int]
    ) {
        self.regionName = regionName
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.targetDateString = targetDateString
        self.referenceUrl = referenceUrl
        self.retrievedAt = retrievedAt
        self.officialTimes = officialTimes
        self.empiricalOffsets = empiricalOffsets
    }
}

// MARK: - Registry Arsip Snapshot SIHAT
public enum SihatSnapshotRegistry {
    /// Arsip snapshot resmi yang terverifikasi secara empiris langsung dari portal Bimas Islam Kemenag RI.
    public static let snapshots: [SihatOfficialSnapshot] = [
        // Snapshot 1: DKI Jakarta - 18 November 2026
        SihatOfficialSnapshot(
            regionName: "DKI Jakarta",
            latitude: -6.2088,
            longitude: 106.8456,
            timeZoneIdentifier: "Asia/Jakarta",
            targetDateString: "2026-11-18",
            referenceUrl: "https://bimasislam.kemenag.go.id/jadwalshalat",
            retrievedAt: "2026-11-18T10:00:00+07:00",
            officialTimes: [
                .fajr: "04:05",
                .sunrise: "05:25",
                .dhuhr: "11:41",
                .asr: "15:03",
                .maghrib: "17:53",
                .isha: "19:06"
            ],
            empiricalOffsets: [
                .fajr: 2,
                .sunrise: 0,
                .dhuhr: 3,
                .asr: 3,
                .maghrib: 3,
                .isha: 2
            ]
        ),
        // Snapshot 2: Surabaya - 18 November 2026
        SihatOfficialSnapshot(
            regionName: "Surabaya",
            latitude: -7.2575,
            longitude: 112.7521,
            timeZoneIdentifier: "Asia/Jakarta",
            targetDateString: "2026-11-18",
            referenceUrl: "https://bimasislam.kemenag.go.id/jadwalshalat",
            retrievedAt: "2026-11-18T10:00:00+07:00",
            officialTimes: [
                .fajr: "03:40",
                .sunrise: "04:57",
                .dhuhr: "11:18",
                .asr: "14:39",
                .maghrib: "17:31",
                .isha: "18:45"
            ],
            empiricalOffsets: [
                .fajr: 3,
                .sunrise: -3,
                .dhuhr: 4,
                .asr: 3,
                .maghrib: 3,
                .isha: 3
            ]
        ),
        // Snapshot 3: DKI Jakarta - 19 November 2026 (Bukti empiris pergeseran delta harian)
        SihatOfficialSnapshot(
            regionName: "DKI Jakarta",
            latitude: -6.2088,
            longitude: 106.8456,
            timeZoneIdentifier: "Asia/Jakarta",
            targetDateString: "2026-11-19",
            referenceUrl: "https://bimasislam.kemenag.go.id/jadwalshalat",
            retrievedAt: "2026-11-18T10:00:00+07:00",
            officialTimes: [
                .fajr: "04:05",
                .sunrise: "05:25",
                .dhuhr: "11:42",
                .asr: "15:04",
                .maghrib: "17:54",
                .isha: "19:07"
            ],
            empiricalOffsets: [
                .fajr: 2,
                .sunrise: -1,
                .dhuhr: 4,
                .asr: 3,
                .maghrib: 4,
                .isha: 3
            ]
        )
    ]
    
    /// Mencari snapshot yang persis cocok untuk nama kota dan tanggal target tertentu.
    public static func match(cityName: String, dateString: String) -> SihatOfficialSnapshot? {
        let normalizedInput = cityName.lowercased()
        return snapshots.first { snapshot in
            guard snapshot.targetDateString == dateString else { return false }
            let normalizedRegion = snapshot.regionName.lowercased()
            
            // Exact match or mutual substring
            if normalizedInput.contains(normalizedRegion) || normalizedRegion.contains(normalizedInput) {
                return true
            }
            
            // Common city root match (e.g. "Jakarta Pusat" or "Jakarta Selatan" -> "DKI Jakarta")
            if normalizedInput.contains("jakarta") && normalizedRegion.contains("jakarta") {
                return true
            }
            if normalizedInput.contains("surabaya") && normalizedRegion.contains("surabaya") {
                return true
            }
            
            return false
        }
    }
}

// MARK: - Kebijakan Ihtiyati
public enum IhtiyatiPolicy: String, CaseIterable, Identifiable, Codable {
    case pureAstronomical = "Astronomis Murni (Offset 0 Menit)"
    case custom = "Koreksi Manual Pengguna (-5 s/d +5m)"
    case experimentalSihatSnapshot = "Eksperimental: Snapshot Terverifikasi SIHAT"
    
    public var id: String { rawValue }
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
    
    private let preferencesKey = "OzillIsland_PrayerPreferences_v4"
    private let locationModeKey = "OzillIsland_LocationMode_v4"
    private let selectedCityKey = "OzillIsland_SelectedCity_v4"
    private let ihtiyatiPolicyKey = "OzillIsland_IhtiyatiPolicy_v4"
    
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
    
    /// Menghitung penyesuaian efektif total dengan semantik ketat dan jujur:
    /// - `.pureAstronomical`: SELALU mengembalikan 0 menit (koreksi manual diabaikan untuk menjamin keaslian hisab murni).
    /// - `.custom`: Murni menggunakan koreksi manual pengguna (-5 s/d +5m).
    /// - `.experimentalSihatSnapshot`: Memeriksa apakah ada snapshot arsip resmi untuk (kota + tanggal).
    ///   Jika cocok: base snapshot + koreksi manual pengguna (status isCalibrated = true).
    ///   Jika TIDAK cocok: fallback ke offset 0 + koreksi manual pengguna, dengan status isCalibrated = false ("Belum Dikalibrasi").
    public func effectiveAdjustment(
        for prayer: PrayerName,
        cityName: String,
        date: Date,
        timeZone: TimeZone
    ) -> (totalMinutes: Int, isCalibrated: Bool, statusExplanation: String) {
        switch ihtiyatiPolicy {
        case .pureAstronomical:
            return (0, true, "Astronomis murni tanpa ihtiyati (Offset 0 menit)")
            
        case .custom:
            let manual = preferences[prayer]?.manualAdjustmentMinutes ?? 0
            let sign = manual > 0 ? "+\(manual)" : "\(manual)"
            return (manual, true, "Koreksi manual pengguna (\(sign)m)")
            
        case .experimentalSihatSnapshot:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = timeZone
            let dateStr = formatter.string(from: date)
            
            if let snapshot = SihatSnapshotRegistry.match(cityName: cityName, dateString: dateStr),
               let baseOffset = snapshot.empiricalOffsets[prayer] {
                let manual = preferences[prayer]?.manualAdjustmentMinutes ?? 0
                let total = baseOffset + manual
                let sign = total > 0 ? "+\(total)" : "\(total)"
                return (total, true, "Snapshot SIHAT Kemenag \(snapshot.regionName) [\(dateStr)] (\(sign)m)")
            } else {
                // Tidak ada snapshot resmi untuk tanggal/kota ini: jangan tebak atau karang!
                let manual = preferences[prayer]?.manualAdjustmentMinutes ?? 0
                let sign = manual > 0 ? "+\(manual)" : "\(manual)"
                return (manual, false, "Belum Dikalibrasi: Tidak ada snapshot resmi SIHAT untuk tanggal \(dateStr). Menggunakan falak mentah (\(sign)m).")
            }
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
            // Batasi koreksi manual secara ketat -5 s/d +5 menit
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
