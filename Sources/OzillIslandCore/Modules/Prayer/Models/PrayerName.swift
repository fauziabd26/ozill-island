import Foundation

public enum PrayerName: String, CaseIterable, Identifiable, Codable {
    case fajr = "Subuh"
    case sunrise = "Syuruq"
    case dhuhr = "Dzuhur"
    case asr = "Ashar"
    case maghrib = "Maghrib"
    case isha = "Isya"
    
    public var id: String { rawValue }
    
    public var sfSymbol: String {
        switch self {
        case .fajr: return "sun.horizon.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
    
    /// Hanya waktu shalat fardhu (5 waktu) untuk adzan & notifikasi
    public var isFardhu: Bool {
        return self != .sunrise
    }
    
    public static var fardhuPrayers: [PrayerName] {
        return [.fajr, .dhuhr, .asr, .maghrib, .isha]
    }
}
