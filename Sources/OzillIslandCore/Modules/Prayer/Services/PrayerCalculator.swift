import Foundation
import Adhan

public struct PrayerCalculator {
    public init() {}
    
    /// Menghitung jadwal shalat lokal dengan parameter astronomi Kemenag RI + koreksi ihtiyati per-waktu
    public func calculate(
        latitude: Double,
        longitude: Double,
        date: Date = Date(),
        timeZone: TimeZone = .current,
        adjustments: [PrayerName: Int] = [:]
    ) -> PrayerSchedule? {
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        // Parameter Kemenag RI:
        // Fajr (Subuh): 20 derajat
        // Isha (Isya): 18 derajat
        // Madhab: Syafi'i (bayangan 1x tinggi benda saat Ashar)
        var params = CalculationMethod.other.params
        params.fajrAngle = 20.0
        params.ishaAngle = 18.0
        params.madhab = .shafi
        
        guard let prayers = PrayerTimes(
            coordinates: coordinates,
            date: components,
            calculationParameters: params
        ) else {
            return nil
        }
        
        // Terapkan koreksi ihtiyati per waktu shalat
        let fajrAdj = Double((adjustments[.fajr] ?? 2) * 60)
        let sunriseAdj = Double((adjustments[.sunrise] ?? 0) * 60)
        let dhuhrAdj = Double((adjustments[.dhuhr] ?? 2) * 60)
        let asrAdj = Double((adjustments[.asr] ?? 2) * 60)
        let maghribAdj = Double((adjustments[.maghrib] ?? 2) * 60)
        let ishaAdj = Double((adjustments[.isha] ?? 2) * 60)
        
        let adjustedFajr = prayers.fajr.addingTimeInterval(fajrAdj)
        let adjustedSunrise = prayers.sunrise.addingTimeInterval(sunriseAdj)
        let adjustedDhuhr = prayers.dhuhr.addingTimeInterval(dhuhrAdj)
        let adjustedAsr = prayers.asr.addingTimeInterval(asrAdj)
        let adjustedMaghrib = prayers.maghrib.addingTimeInterval(maghribAdj)
        let adjustedIsha = prayers.isha.addingTimeInterval(ishaAdj)
        
        return PrayerSchedule(
            date: date,
            fajr: adjustedFajr,
            sunrise: adjustedSunrise,
            dhuhr: adjustedDhuhr,
            asr: adjustedAsr,
            maghrib: adjustedMaghrib,
            isha: adjustedIsha
        )
    }
}
