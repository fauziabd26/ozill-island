import Foundation
import OzillIslandCore

print("🚀 Menjalankan Validasi Otomatis Ozill Island (Prayer Times Engine)...")

let calculator = PrayerCalculator()
let jakarta = CityPreset.defaultCity
guard let tz = TimeZone(identifier: "Asia/Jakarta") else {
    fatalError("❌ Timezone Asia/Jakarta tidak ditemukan")
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = tz

var dateComponents = DateComponents()
dateComponents.year = 2026
dateComponents.month = 11
dateComponents.day = 18
guard let testDate = calendar.date(from: dateComponents) else {
    fatalError("❌ Gagal membuat testDate")
}

// 1. Validasi Perhitungan Standar Kemenag RI (+2 menit Ihtiyati)
let kemenagAdjustments: [PrayerName: Int] = [
    .fajr: 2,
    .sunrise: 0,
    .dhuhr: 2,
    .asr: 2,
    .maghrib: 2,
    .isha: 2
]

guard let schedule = calculator.calculate(
    latitude: jakarta.latitude,
    longitude: jakarta.longitude,
    date: testDate,
    timeZone: tz,
    adjustments: kemenagAdjustments
) else {
    fatalError("❌ Gagal menghitung jadwal shalat")
}

let fajrTime = schedule.formattedTime(for: .fajr, timeZone: tz)
let sunriseTime = schedule.formattedTime(for: .sunrise, timeZone: tz)
let dhuhrTime = schedule.formattedTime(for: .dhuhr, timeZone: tz)
let asrTime = schedule.formattedTime(for: .asr, timeZone: tz)
let maghribTime = schedule.formattedTime(for: .maghrib, timeZone: tz)
let ishaTime = schedule.formattedTime(for: .isha, timeZone: tz)

print("\n==================================================")
print("📅 Tanggal Uji: 18 November 2026")
print("📍 Lokasi: \(jakarta.name) (Lat: \(jakarta.latitude), Lon: \(jakarta.longitude))")
print("🕋 Standar: Kemenag RI (Subuh 20°, Isya 18°, Syafi'i, Ihtiyati +2m)")
print("==================================================")
print("  Subuh:   \(fajrTime) WIB")
print("  Syuruq:  \(sunriseTime) WIB")
print("  Dzuhur:  \(dhuhrTime) WIB")
print("  Ashar:   \(asrTime) WIB")
print("  Maghrib: \(maghribTime) WIB")
print("  Isya:    \(ishaTime) WIB")
print("==================================================")

// Verifikasi urutan kronologis
assert(schedule.fajr < schedule.sunrise, "Subuh harus sebelum Syuruq")
assert(schedule.sunrise < schedule.dhuhr, "Syuruq harus sebelum Dzuhur")
assert(schedule.dhuhr < schedule.asr, "Dzuhur harus sebelum Ashar")
assert(schedule.asr < schedule.maghrib, "Ashar harus sebelum Maghrib")
assert(schedule.maghrib < schedule.isha, "Maghrib harus sebelum Isya")
print("✅ Verifikasi Urutan Kronologis: BERHASIL")

// 2. Validasi Koreksi Manual / Configurable Ihtiyati
let customAdjustments: [PrayerName: Int] = [
    .fajr: 5,
    .maghrib: -3
]
guard let customSchedule = calculator.calculate(
    latitude: jakarta.latitude,
    longitude: jakarta.longitude,
    date: testDate,
    timeZone: tz,
    adjustments: customAdjustments
) else {
    fatalError("❌ Gagal menghitung custom schedule")
}

let fajrDiff = Int(customSchedule.fajr.timeIntervalSince(schedule.fajr))
// Custom fajr (+5) vs default (+2) = selisih 3 menit (180 detik)
assert(fajrDiff == 180, "Selisih Fajr harus tepat 180 detik (3 menit)")
print("✅ Verifikasi Configurable Ihtiyati / Koreksi Manual: BERHASIL")

// 3. Validasi Preset Kota
assert(!CityPreset.defaults.isEmpty, "Daftar kota preset tidak boleh kosong")
assert(CityPreset.defaultCity.name == "DKI Jakarta", "Default city harus DKI Jakarta")
print("✅ Verifikasi Fallback City Preset: BERHASIL (\(CityPreset.defaults.count) kota Indonesia)")

// 4. Validasi Audio Asset
let audioUrl = AdhanAudioManager.sampleAudioURL
assert(audioUrl != nil, "Audio resource AdhanSample.wav harus ada di bundle module")
print("✅ Verifikasi Resource Audio Bundle: BERHASIL")

print("\n🎉 SEMUA ACCEPTANCE CRITERIA PRAYER TIME ENGINE TERPENUHI 100%!\n")
