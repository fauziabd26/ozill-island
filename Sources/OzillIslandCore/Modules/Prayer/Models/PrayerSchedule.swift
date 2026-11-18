import Foundation

public struct PrayerSchedule: Codable {
    public let date: Date
    public let fajr: Date
    public let sunrise: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    
    public init(date: Date, fajr: Date, sunrise: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date) {
        self.date = date
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }
    
    public func time(for prayer: PrayerName) -> Date {
        switch prayer {
        case .fajr: return fajr
        case .sunrise: return sunrise
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }
    
    public var items: [(prayer: PrayerName, time: Date)] {
        return [
            (.fajr, fajr),
            (.sunrise, sunrise),
            (.dhuhr, dhuhr),
            (.asr, asr),
            (.maghrib, maghrib),
            (.isha, isha)
        ]
    }
    
    /// Menentukan jadwal shalat berikutnya dari waktu sekarang
    public func nextPrayer(from referenceDate: Date = Date()) -> (prayer: PrayerName, time: Date) {
        for item in items where item.time > referenceDate {
            return item
        }
        // Jika sudah lewat Isya, shalat berikutnya adalah Subuh besok
        let tomorrowFajr = fajr.addingTimeInterval(86400)
        return (.fajr, tomorrowFajr)
    }
    
    /// Menentukan shalat saat ini (shalat terakhir yang sudah masuk)
    public func currentPrayer(from referenceDate: Date = Date()) -> (prayer: PrayerName, time: Date)? {
        let passed = items.filter { $0.time <= referenceDate }
        return passed.last
    }
    
    /// Format waktu ke string HH:mm dengan timezone lokal
    public func formattedTime(for prayer: PrayerName, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: time(for: prayer))
    }
}
