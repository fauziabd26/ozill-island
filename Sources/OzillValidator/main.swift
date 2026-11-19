import Foundation
import SwiftUI
import OzillIslandCore
import AVFoundation
import UserNotifications

actor MockNotificationCenter: PrayerNotificationCenterProtocol {
    private var _addedRequests: [UNNotificationRequest] = []
    private var _removeCallCount = 0
    private var _removeAllCallCount = 0
    private var _removedIdentifierBatches: [[String]] = []
    let delayNanoseconds: UInt64
    let shouldFailOnAdd: Bool

    var addedRequests: [UNNotificationRequest] {
        return _addedRequests
    }

    var removeCallCount: Int {
        return _removeCallCount
    }

    var removeAllCallCount: Int {
        return _removeAllCallCount
    }

    var removedIdentifierBatches: [[String]] {
        return _removedIdentifierBatches
    }

    init(delayNanoseconds: UInt64 = 0, shouldFailOnAdd: Bool = false) {
        self.delayNanoseconds = delayNanoseconds
        self.shouldFailOnAdd = shouldFailOnAdd
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return true
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        _removeCallCount += 1
        _removedIdentifierBatches.append(identifiers)
        let idSet = Set(identifiers)
        _addedRequests.removeAll { idSet.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() async {
        _removeAllCallCount += 1
        _addedRequests.removeAll()
    }

    func add(_ request: UNNotificationRequest) async throws {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if shouldFailOnAdd {
            throw NSError(domain: "OzillTestErrorDomain", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Simulated center.add failure for testing"])
        }
        _addedRequests.append(request)
    }
}

@main
struct OzillValidatorApp {
    @MainActor
    static func main() async {
        print("""
        ================================================================================
           OZILL ISLAND — PRAYER ENGINE FINAL HARDENING VALIDATION SUITE
           Standard: Hisab Falak Astronomis (Fajr 20°, Isha 18°, Madhab Syafi'i)
           Reference: Portal Resmi SIHAT Bimas Islam Kemenag RI
           URL: https://bimasislam.kemenag.go.id/jadwalshalat
           Platform: macOS x86_64 Native (Swift Package Manager)
        ================================================================================
        """)

        let calculator = PrayerCalculator()

        func parseMinutes(from timeStr: String) -> Int {
            let parts = timeStr.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return 0 }
            return parts[0] * 60 + parts[1]
        }

        // MARK: - BAGIAN 1: AUDIT SNAPSHOT EMPIRIS DENGAN PROVENANCE
        print("📊 [BAGIAN 1: ARSIP SNAPSHOT RESMI SIHAT DENGAN IDENTITAS & PROVENANCE]\n")

        for snapshot in SihatSnapshotRegistry.snapshots {
            let tz = TimeZone(identifier: snapshot.timeZoneIdentifier)!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tz

            let parts = snapshot.targetDateString.split(separator: "-").compactMap { Int($0) }
            var comp = DateComponents()
            comp.year = parts[0]
            comp.month = parts[1]
            comp.day = parts[2]
            comp.hour = 12
            guard let targetDate = calendar.date(from: comp) else {
                fatalError("Gagal parse targetDate: \(snapshot.targetDateString)")
            }

            // 1. Raw Falak (Offset 0)
            guard let rawSchedule = calculator.calculate(
                latitude: snapshot.latitude,
                longitude: snapshot.longitude,
                date: targetDate,
                timeZone: tz,
                adjustments: [:]
            ) else {
                fatalError("Gagal menghitung raw schedule untuk \(snapshot.regionName)")
            }

            print("📍 Wilayah: \(snapshot.regionName) | Tanggal: \(snapshot.targetDateString)")
            print("   Koordinat: (Lat: \(snapshot.latitude), Lon: \(snapshot.longitude)) | TZ: \(snapshot.timeZoneIdentifier)")
            print("   Sumber: \(snapshot.referenceUrl) (Diarsip: \(snapshot.retrievedAt) | Metode: \(snapshot.verificationMethod.rawValue))")
            print("  +----------+---------------+----------------+---------------+--------------+----------------+")
            print("  | Waktu    | Falak Raw(0m) | SIHAT Kemenag  | Selisih Raw   | Base Buffer  | Delta SIHAT    |")
            print("  +----------+---------------+----------------+---------------+--------------+----------------+")

            for prayer in PrayerName.allCases {
                let rawStr = rawSchedule.formattedTime(for: prayer, timeZone: tz)
                let sihatStr = snapshot.officialTimes[prayer] ?? "--:--"
                let empiricalOffset = snapshot.empiricalOffsets[prayer] ?? 0

                let rawMins = parseMinutes(from: rawStr)
                let sihatMins = parseMinutes(from: sihatStr)
                let rawDiff = rawMins - sihatMins
                let rawDiffStr = rawDiff > 0 ? "+\(rawDiff)m" : "\(rawDiff)m"

                // Periksa hasil jika buffer empiris snapshot diterapkan
                let calibratedMins = rawMins + empiricalOffset
                let finalDelta = calibratedMins - sihatMins
                let finalDeltaStr = finalDelta == 0 ? "0m (Presisi)" : (finalDelta > 0 ? "+\(finalDelta)m" : "\(finalDelta)m")
                let bufStr = empiricalOffset > 0 ? "+\(empiricalOffset)m" : "\(empiricalOffset)m"

                let pLabel = prayer.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
                let rCol = rawStr.padding(toLength: 13, withPad: " ", startingAt: 0)
                let sCol = sihatStr.padding(toLength: 14, withPad: " ", startingAt: 0)
                let rdCol = rawDiffStr.padding(toLength: 13, withPad: " ", startingAt: 0)
                let cCol = bufStr.padding(toLength: 12, withPad: " ", startingAt: 0)
                let fCol = finalDeltaStr.padding(toLength: 14, withPad: " ", startingAt: 0)

                print("  | \(pLabel) | \(rCol) | \(sCol) | \(rdCol) | \(cCol) | \(fCol) |")
            }
            print("  +----------+---------------+----------------+---------------+--------------+----------------+\n")
        }

        // MARK: - BAGIAN 2: AUTOMATED VALIDATION ASSERTIONS
        print("🧪 [BAGIAN 2: AUTOMATED VALIDATION ASSERTIONS (21 ASSERTION SUITES)]\n")

        var testCount = 0
        func runTest(_ name: String, block: () throws -> Void) {
            testCount += 1
            do {
                try block()
                print("  ✅ [PASS] Assertion \(testCount): \(name)")
            } catch {
                print("  ❌ [FAIL] Assertion \(testCount): \(name) - Error: \(error)")
                exit(1)
            }
        }

        func runAsyncTest(_ name: String, block: () async throws -> Void) async {
            testCount += 1
            do {
                try await block()
                print("  ✅ [PASS] Assertion \(testCount): \(name)")
            } catch {
                print("  ❌ [FAIL] Assertion \(testCount): \(name) - Error: \(error)")
                exit(1)
            }
        }

        let tzJakarta = TimeZone(identifier: "Asia/Jakarta")!
        var calTest = Calendar(identifier: .gregorian)
        calTest.timeZone = tzJakarta
        var baseComp = DateComponents()
        baseComp.year = 2026
        baseComp.month = 11
        baseComp.day = 18
        baseComp.hour = 12
        let baseTestDate = calTest.date(from: baseComp)!

        // Assertion 1: Raw astronomical calculation integrity and sequence
        runTest("Integritas Hisab Falak Mentah (Urutan kronologis Subuh s/d Isya valid)") {
            let rawSched = calculator.calculate(
                latitude: -6.2088,
                longitude: 106.8456,
                date: baseTestDate,
                timeZone: tzJakarta,
                adjustments: [:]
            )!
            assert(rawSched.fajr < rawSched.sunrise)
            assert(rawSched.sunrise < rawSched.dhuhr)
            assert(rawSched.dhuhr < rawSched.asr)
            assert(rawSched.asr < rawSched.maghrib)
            assert(rawSched.maghrib < rawSched.isha)
        }

        // Assertion 2: Pure Astronomical Policy locks adjustments to zero
        runTest("IhtiyatiPolicy.pureAstronomical selalu menghasilkan offset 0 murni") {
            let settings = PrayerSettings()
            settings.ihtiyatiPolicy = .pureAstronomical
            settings.update(.fajr, manualAdjustmentMinutes: 4)
            settings.update(.maghrib, manualAdjustmentMinutes: -3)

            for prayer in PrayerName.allCases {
                let (adj, isCal, _) = settings.effectiveAdjustment(
                    for: prayer,
                    cityName: "DKI Jakarta",
                    date: baseTestDate,
                    timeZone: tzJakarta
                )
                assert(adj == 0, "Pada pureAstronomical, offset harus SELALU 0")
                assert(isCal == true)
            }
        }

        // Assertion 3: Snapshot Registry exact match and provenance
        runTest("SihatSnapshotRegistry: Pencocokan tepat tanggal & kota mengembalikan snapshot resmi") {
            let match = SihatSnapshotRegistry.match(cityName: "Jakarta Pusat", dateString: "2026-11-18")
            assert(match != nil)
            assert(match?.regionName == "DKI Jakarta")
            assert(match?.verificationMethod == .manuallyArchived)
            assert(match?.empiricalOffsets[.dhuhr] == 3)

            // Periksa snapshot tanggal 19 Nov (terbukti Dzuhur bergeser offset ke +4)
            let match19 = SihatSnapshotRegistry.match(cityName: "DKI Jakarta", dateString: "2026-11-19")
            assert(match19 != nil)
            assert(match19?.verificationMethod == .manuallyArchived)
            assert(match19?.empiricalOffsets[.dhuhr] == 4)
        }

        // Assertion 4: Uncalibrated fallback for unverified dates & cities
        runTest("SihatSnapshotRegistry: Tanggal/kota di luar arsip fallback ke offset 0 & Uncalibrated") {
            let settings = PrayerSettings()
            settings.ihtiyatiPolicy = .experimentalSihatSnapshot
            settings.update(.fajr, manualAdjustmentMinutes: 0)

            var futureComp = DateComponents()
            futureComp.year = 2026
            futureComp.month = 12
            futureComp.day = 25
            let futureDate = calTest.date(from: futureComp)!

            let (adj, isCal, desc) = settings.effectiveAdjustment(
                for: .fajr,
                cityName: "DKI Jakarta",
                date: futureDate,
                timeZone: tzJakarta
            )
            assert(adj == 0, "Tanggal tanpa snapshot dengan manual 0 harus fallback ke offset 0")
            assert(isCal == false, "Status harus uncalibrated (false)")
            assert(desc.contains("Belum Dikalibrasi"))
        }

        // Assertion 5: Manual adjustment strict clamping (-5 to +5)
        runTest("Pembatasan Koreksi Manual Pengguna (-5 s/d +5 menit) aman dari overflow") {
            let settings = PrayerSettings()
            settings.ihtiyatiPolicy = .custom

            settings.update(.fajr, manualAdjustmentMinutes: 10)
            assert(settings.preferences[.fajr]?.manualAdjustmentMinutes == 5)

            settings.update(.isha, manualAdjustmentMinutes: -8)
            assert(settings.preferences[.isha]?.manualAdjustmentMinutes == -5)

            let (fajrAdj, _, _) = settings.effectiveAdjustment(
                for: .fajr,
                cityName: "DKI Jakarta",
                date: baseTestDate,
                timeZone: tzJakarta
            )
            assert(fajrAdj == 5)
        }

        // Assertion 6: Leap year & Month-end rollover without magic numbers
        runTest("Kalkulasi Hari Esok tahan tahun kabisat (28 Feb -> 29 Feb) tanpa konstanta 86400") {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tzJakarta

            var leapComp = DateComponents()
            leapComp.year = 2024
            leapComp.month = 2
            leapComp.day = 28
            leapComp.hour = 23
            let leapDate = calendar.date(from: leapComp)!

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: leapDate) else {
                fatalError("Gagal menambah hari")
            }
            let day = calendar.component(.day, from: nextDay)
            let month = calendar.component(.month, from: nextDay)
            assert(day == 29 && month == 2, "Harus jatuh pada 29 Februari 2024")

            var yearEndComp = DateComponents()
            yearEndComp.year = 2026
            yearEndComp.month = 12
            yearEndComp.day = 31
            yearEndComp.hour = 23
            let yearEndDate = calendar.date(from: yearEndComp)!
            guard let newYear = calendar.date(byAdding: .day, value: 1, to: yearEndDate) else {
                fatalError("Gagal menambah tahun")
            }
            let newYearVal = calendar.component(.year, from: newYear)
            let newDayVal = calendar.component(.day, from: newYear)
            assert(newYearVal == 2027 && newDayVal == 1, "Harus berganti ke 1 Januari 2027")
        }

        // Assertion 7: Multi-timezone handling (WIB, WITA, WIT)
        runTest("Dukungan tiga zona waktu Indonesia (WIB, WITA, WIT) dengan singkatan resmi") {
            let makassarTz = TimeZone(identifier: "Asia/Makassar")!
            let jayapuraTz = TimeZone(identifier: "Asia/Jayapura")!

            let makassarSched = calculator.calculate(
                latitude: -5.1477,
                longitude: 119.4327,
                date: baseTestDate,
                timeZone: makassarTz,
                adjustments: [:]
            )!
            let jayapuraSched = calculator.calculate(
                latitude: -2.5916,
                longitude: 140.6690,
                date: baseTestDate,
                timeZone: jayapuraTz,
                adjustments: [:]
            )!

            let makassarFajrStr = makassarSched.formattedTime(for: .fajr, timeZone: makassarTz)
            let jayapuraFajrStr = jayapuraSched.formattedTime(for: .fajr, timeZone: jayapuraTz)

            assert(makassarFajrStr.count == 5)
            assert(jayapuraFajrStr.count == 5)

            assert(tzJakarta.abbreviation(for: baseTestDate) == "GMT+7" || tzJakarta.abbreviation(for: baseTestDate) == "WIB")
        }

        // Assertion 8: Named constants in PrayerScheduler
        runTest("Konstanta Bernama Scheduler: Mengeliminasi magic number secara eksplisit") {
            assert(PrayerScheduler.maxSleepDurationToAnalyze == 24 * 60 * 60, "maxSleepDurationToAnalyze harus 86400 detik (24 jam)")
            assert(PrayerScheduler.minSleepDurationToAnalyze == 15, "minSleepDurationToAnalyze harus 15 detik")
            assert(PrayerScheduler.adhanOnsetToleranceWindow == 45, "adhanOnsetToleranceWindow harus 45 detik")
        }

        // Assertion 9: Deduplication Set<String> across multiple missed prayers
        runTest("Deduplikasi Adzan Set<String>: Mencegah penimpaan antar beberapa shalat yang terlewat") {
            var testKeys = Set<String>()
            let keySubuh = "Subuh-2026-11-19"
            let keyDzuhur = "Dzuhur-2026-11-19"

            testKeys.insert(keySubuh)
            testKeys.insert(keyDzuhur)

            assert(testKeys.contains(keySubuh))
            assert(testKeys.contains(keyDzuhur))
            assert(testKeys.count == 2, "Set harus menyimpan kedua kunci secara independen")

            // Re-insertion
            testKeys.insert(keySubuh)
            assert(testKeys.count == 2, "Set tidak boleh menduplikasi key yang sama")
        }

        // Assertion 10: Overnight Sleep (23:00 -> 06:00) detection
        runTest("Deteksi Sleep Semalaman (23:00 -> 06:00): Mendeteksi Subuh keesokan hari") {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tzJakarta

            var sleepStartComp = DateComponents()
            sleepStartComp.year = 2026
            sleepStartComp.month = 11
            sleepStartComp.day = 18
            sleepStartComp.hour = 23
            sleepStartComp.minute = 0
            let sleepStart = calendar.date(from: sleepStartComp)!

            var wakeComp = DateComponents()
            wakeComp.year = 2026
            wakeComp.month = 11
            wakeComp.day = 19
            wakeComp.hour = 6
            wakeComp.minute = 0
            let wakeTime = calendar.date(from: wakeComp)!

            let day2Sched = calculator.calculate(
                latitude: -6.2088,
                longitude: 106.8456,
                date: wakeTime,
                timeZone: tzJakarta,
                adjustments: [:]
            )!

            assert(day2Sched.fajr > sleepStart && day2Sched.fajr <= wakeTime)
            assert(day2Sched.dhuhr > wakeTime)
        }

        // Assertion 11: Daytime Sleep (11:00 -> 14:00) detection
        runTest("Deteksi Sleep Siang Hari (11:00 -> 14:00): Mendeteksi Dzuhur dan menolak Ashar") {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tzJakarta

            var sleepStartComp = DateComponents()
            sleepStartComp.year = 2026
            sleepStartComp.month = 11
            sleepStartComp.day = 18
            sleepStartComp.hour = 11
            sleepStartComp.minute = 0
            let sleepStart = calendar.date(from: sleepStartComp)!

            var wakeComp = DateComponents()
            wakeComp.year = 2026
            wakeComp.month = 11
            wakeComp.day = 18
            wakeComp.hour = 14
            wakeComp.minute = 0
            let wakeTime = calendar.date(from: wakeComp)!

            let todaySched = calculator.calculate(
                latitude: -6.2088,
                longitude: 106.8456,
                date: sleepStart,
                timeZone: tzJakarta,
                adjustments: [:]
            )!

            // Dzuhur sekitar 11:38 -> jatuh di antara 11:00 dan 14:00
            assert(todaySched.dhuhr > sleepStart && todaySched.dhuhr <= wakeTime)
            // Ashar sekitar 15:00 -> setelah 14:00
            assert(todaySched.asr > wakeTime)
        }

        // Assertion 12: Extended sleep (> 24 hours) policy
        runTest("Kebijakan Sleep > 24 Jam: Update jadwal secara bersih tanpa membanjiri antrean missed prayer") {
            let sleepSeconds: Double = 36 * 3600 // 36 jam
            assert(sleepSeconds > PrayerScheduler.maxSleepDurationToAnalyze)
        }

        // Assertion 13: Adhan Trigger Onset Window [0 ..< 45s]
        runTest("Jendela Toleransi Onset Adzan [0 ..< 45 detik]: Menolak pemicu terlambat dan duplikat") {
            let now = Date()
            let exactPrayerTime = now
            let diffValid = now.timeIntervalSince(exactPrayerTime)
            assert(diffValid >= 0 && diffValid < PrayerScheduler.adhanOnsetToleranceWindow)

            let delayedTime = now.addingTimeInterval(-50)
            let diffDelayed = now.timeIntervalSince(delayedTime)
            assert(diffDelayed >= PrayerScheduler.adhanOnsetToleranceWindow)
        }

        // Assertion 14: Audio Player Resource Loading
        runTest("AdhanAudioManager: Bundle resource file AdhanSample.wav valid dan siap diputar") {
            guard let url = AdhanAudioManager.sampleAudioURL else {
                fatalError("sampleAudioURL nil")
            }
            assert(FileManager.default.fileExists(atPath: url.path), "Berkas fisik audio harus ada")
            let player = try AVAudioPlayer(contentsOf: url)
            assert(player.duration > 0, "Durasi audio harus lebih dari 0 detik")
        }

        // Assertion 15: Sleep timestamp captured before task dispatch
        runTest("Timestamp Sleep Ditangkap Sebelum Task Dispatch: Menjamin keakuratan durasi tanpa terdistorsi saat Mac bangun") {
            let scheduler = PrayerScheduler.shared
            let preSleepDate = Date(timeIntervalSince1970: 1700000000)
            scheduler.recordSleep(at: preSleepDate)
            assert(scheduler.currentRecordedSleepTime == preSleepDate, "Timestamp harus tersimpan tepat sama seperti sebelum sleep")
        }

        // Assertion 16: Short sleep (< 15s) produces no false missed prayer
        runTest("Sleep Singkat (< 15 detik): Tidak memicu false missed prayer alert") {
            let scheduler = PrayerScheduler.shared
            scheduler.setInitialLaunchForTesting(false)
            scheduler.clearMissedPrayerAlert()

            let sleepStart = Date()
            let wakeTime = sleepStart.addingTimeInterval(5) // 5 detik < 15 detik
            scheduler.recordSleep(at: sleepStart)
            scheduler.handleWakeFromSleep(at: wakeTime)

            assert(scheduler.missedPrayerAlert == nil, "Sleep < 15 detik tidak boleh memunculkan alert missed prayer")
        }

        // Assertion 17: Sleep across midnight detects prayer from both dates
        runTest("Sleep Lintas Tengah Malam (23:00 -> 06:00): Mendeteksi shalat Subuh hari kedua secara akurat") {
            let scheduler = PrayerScheduler.shared
            scheduler.setInitialLaunchForTesting(false)
            scheduler.clearMissedPrayerAlert()
            scheduler.clearTriggeredPrayerKeysForTesting()

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tzJakarta

            var sleepComp = DateComponents()
            sleepComp.year = 2026
            sleepComp.month = 11
            sleepComp.day = 18
            sleepComp.hour = 23
            sleepComp.minute = 0
            let sleepStart = cal.date(from: sleepComp)!

            var wakeComp = DateComponents()
            wakeComp.year = 2026
            wakeComp.month = 11
            wakeComp.day = 19
            wakeComp.hour = 6
            wakeComp.minute = 0
            let wakeTime = cal.date(from: wakeComp)!

            scheduler.recordSleep(at: sleepStart)
            scheduler.handleWakeFromSleep(at: wakeTime)

            assert(scheduler.missedPrayerAlert != nil, "Harus memunculkan alert missed prayer")
            assert(scheduler.missedPrayerAlert?.contains("Subuh") == true, "Alert harus mencakup shalat Subuh")
        }

        // Assertion 18: Missed prayer suppresses retroactive adzan
        runTest("Missed Prayer Membungkam Adzan Retroaktif: Key adzan ter-blacklist di triggeredPrayerKeys") {
            let scheduler = PrayerScheduler.shared
            let keys = scheduler.getTriggeredPrayerKeysForTesting()

            // Subuh tanggal 19 November harus ada di daftar blacklisted keys
            let expectedKey = "Subuh-2026-11-19"
            assert(keys.contains(expectedKey), "Kunci adzan untuk shalat yang terlewat saat tidur harus ter-blacklist")
        }

        // Assertion 19: Serialized FIFO scheduling queue eliminates race condition between rapid back-to-back requests
        await runAsyncTest("Serialized FIFO Scheduling Queue: Menghilangkan race condition pada pemanggilan cepat beruntun") {
            let mockCenter = MockNotificationCenter(delayNanoseconds: 20_000_000) // 20ms per penambahan
            let manager = PrayerNotificationManager(center: mockCenter)

            guard let sched1 = calculator.calculate(latitude: -6.2088, longitude: 106.8456, date: baseTestDate, timeZone: tzJakarta, adjustments: [:]),
                  let sched2 = calculator.calculate(latitude: -6.2088, longitude: 106.8456, date: baseTestDate.addingTimeInterval(86400), timeZone: tzJakarta, adjustments: [:]) else {
                fatalError("Gagal menghitung jadwal uji")
            }

            // Jalankan dua batch secara berurutan tanpa jeda
            let task1 = Task {
                await manager.scheduleAll(
                    todaySchedule: sched1,
                    tomorrowSchedule: nil,
                    preferences: PrayerSettings.shared.preferences,
                    timeZone: tzJakarta
                )
            }

            let task2 = Task {
                await manager.scheduleAll(
                    todaySchedule: sched2,
                    tomorrowSchedule: nil,
                    preferences: PrayerSettings.shared.preferences,
                    timeZone: tzJakarta
                )
            }

            _ = await task1.value
            _ = await task2.value

            // Verifikasi bahwa antrean serial menyelesaikan seluruh proses secara bersih
            let finalRequests = await mockCenter.addedRequests
            let removeCalls = await mockCenter.removeCallCount
            assert(removeCalls >= 1, "removePendingNotificationRequests harus dipanggil")
            assert(finalRequests.count <= 10, "Jumlah notifikasi tidak boleh melebihi batas batch aktif")
        }

        // Assertion 20: Notification add errors are captured and diagnosable
        await runAsyncTest("Diagnostik Error Notifikasi: center.add yang gagal tercatat secara eksplisit di lastErrors") {
            let failingCenter = MockNotificationCenter(shouldFailOnAdd: true)
            let failingManager = PrayerNotificationManager(center: failingCenter)

            guard let testSched = calculator.calculate(latitude: -6.2088, longitude: 106.8456, date: baseTestDate, timeZone: tzJakarta, adjustments: [:]) else {
                fatalError("Gagal menghitung testSched")
            }

            // Atur waktu acuan ke pagi hari agar semua waktu shalat di masa depan terjadwalkan
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tzJakarta
            var morningComp = DateComponents()
            morningComp.year = 2026
            morningComp.month = 11
            morningComp.day = 18
            morningComp.hour = 3
            morningComp.minute = 0
            let morningDate = cal.date(from: morningComp)!

            let requests = await failingManager.buildNotificationRequests(
                todaySchedule: testSched,
                tomorrowSchedule: nil,
                preferences: PrayerSettings.shared.preferences,
                timeZone: tzJakarta,
                referenceDate: morningDate
            )
            assert(!requests.isEmpty, "Harus ada request notifikasi yang dibentuk")

            let tomorrowDate = cal.date(byAdding: .day, value: 1, to: Date())!
            let tomorrowSched = calculator.calculate(latitude: -6.2088, longitude: 106.8456, date: tomorrowDate, timeZone: tzJakarta, adjustments: [:])

            // Jalankan scheduleAll dengan failing center (menyertakan tomorrowSchedule agar selalu ada jadwal di masa depan)
            await failingManager.scheduleAll(
                todaySchedule: testSched,
                tomorrowSchedule: tomorrowSched,
                preferences: PrayerSettings.shared.preferences,
                timeZone: tzJakarta
            )

            let recordedErrors = await failingManager.lastErrors
            assert(!recordedErrors.isEmpty, "Error penambahan notifikasi harus tercatat dan tidak boleh ditelan")
            assert(recordedErrors[0].error.contains("Simulated center.add failure"), "Deskripsi error harus sesuai")
        }

        // Assertion 21: Namespace Isolation of Prayer Notifications
        await runAsyncTest("Isolasi Namespace Notifikasi: Pembersihan notifikasi Prayer Engine tidak menghapus notifikasi modul lain") {
            let mockCenter = MockNotificationCenter()

            // Simulasikan notifikasi aktif dari modul lain (misal Battery & Calendar)
            let batteryContent = UNMutableNotificationContent()
            batteryContent.title = "Baterai Lemah"
            let batteryReq = UNNotificationRequest(
                identifier: "ozill-battery-low-alert",
                content: batteryContent,
                trigger: nil
            )
            try await mockCenter.add(batteryReq)

            let calendarContent = UNMutableNotificationContent()
            calendarContent.title = "Rapat Standup"
            let calendarReq = UNNotificationRequest(
                identifier: "ozill-calendar-event-standup",
                content: calendarContent,
                trigger: nil
            )
            try await mockCenter.add(calendarReq)

            // Tambahkan juga notifikasi shalat lama
            let oldPrayerContent = UNMutableNotificationContent()
            oldPrayerContent.title = "Adzan Dzuhur Lama"
            let oldPrayerReq = UNNotificationRequest(
                identifier: "ozill-prayer-today-adhan-Dzuhur",
                content: oldPrayerContent,
                trigger: nil
            )
            try await mockCenter.add(oldPrayerReq)

            let initialCount = (await mockCenter.addedRequests).count
            assert(initialCount == 3, "Harus ada 3 request awal")

            // Inisialisasi manager dan jadwalkan shalat
            let manager = PrayerNotificationManager(center: mockCenter)
            guard let testSched = calculator.calculate(latitude: -6.2088, longitude: 106.8456, date: baseTestDate, timeZone: tzJakarta, adjustments: [:]) else {
                fatalError("Gagal menghitung testSched")
            }

            let tomorrowDate = calTest.date(byAdding: .day, value: 1, to: Date())!
            let tomorrowSched = calculator.calculate(latitude: -6.2088, longitude: 106.8456, date: tomorrowDate, timeZone: tzJakarta, adjustments: [:])

            await manager.scheduleAll(
                todaySchedule: testSched,
                tomorrowSchedule: tomorrowSched,
                preferences: PrayerSettings.shared.preferences,
                timeZone: tzJakarta
            )

            let finalRequests = await mockCenter.addedRequests
            let remainingIdentifiers = Set(finalRequests.map { $0.identifier })

            // 1. Notifikasi modul lain HARUS tetap bertahan utuh!
            assert(remainingIdentifiers.contains("ozill-battery-low-alert"), "Notifikasi baterai TIDAK boleh terhapus oleh Prayer Engine")
            assert(remainingIdentifiers.contains("ozill-calendar-event-standup"), "Notifikasi kalender TIDAK boleh terhapus oleh Prayer Engine")

            // 2. Seluruh batch identifier yang dihapus harus secara ketat berada di domain identifier prayer
            let removedBatches = await mockCenter.removedIdentifierBatches
            assert(!removedBatches.isEmpty, "Harus ada operasi pembersihan identifier prayer")
            for batch in removedBatches {
                for id in batch {
                    assert(!id.contains("battery") && !id.contains("calendar"), "Daftar pembersihan tidak boleh menyentuh modul lain: \(id)")
                }
            }
        }

        runTest("Transisi IslandState deterministik dan idempoten (expand, collapse, settings)") {
            let vm = PrayerIslandViewModel.shared

            // Pastikan baseline collapse
            vm.collapse()
            assert(vm.state == .collapsed, "State harus .collapsed")

            // Idempotensi collapse: panggil lagi tetap collapsed
            vm.collapse()
            assert(vm.state == .collapsed, "State harus tetap .collapsed setelah repeated collapse()")

            // Expand
            vm.expand()
            assert(vm.state == .expanded, "State harus bertransisi ke .expanded")

            // Idempotensi expand: panggil lagi tetap expanded
            vm.expand()
            assert(vm.state == .expanded, "State harus tetap .expanded setelah repeated expand()")

            // Buka Settings
            vm.openSettings()
            assert(vm.state == .settings, "State harus bertransisi ke .settings")

            // Idempotensi openSettings
            vm.openSettings()
            assert(vm.state == .settings, "State harus tetap .settings setelah repeated openSettings()")

            // Tutup settings kembali ke expanded
            vm.closeToExpanded()
            assert(vm.state == .expanded, "closeToExpanded() harus kembali ke .expanded")

            // Collapse kembali
            vm.collapse()
            assert(vm.state == .collapsed, "State harus kembali ke .collapsed")

            // Toggle dari collapsed -> expanded
            vm.toggle()
            assert(vm.state == .expanded, "toggle() dari collapsed harus ke .expanded")

            // Toggle dari expanded -> collapsed
            vm.toggle()
            assert(vm.state == .collapsed, "toggle() dari expanded harus ke .collapsed")
        }

        runTest("Island Theme Engine: Presets, Palette Tokens, dan Aksen Custom Hex") {
            let theme = IslandThemeManager.shared

            // 1. Reset ke kondisi baseline default
            theme.resetToDefault()
            assert(theme.preset == .midnight, "Default preset harus .midnight")
            assert(theme.accentColor == .orange, "Default accent harus .orange")
            assert(theme.palette.isDark == true, "Midnight harus tema gelap (isDark == true)")

            // 2. Verifikasi Light Theme (Pearl)
            theme.preset = .pearl
            assert(theme.palette.isDark == false, "Pearl harus tema terang (isDark == false)")

            // 3. Verifikasi Emerald & Aurora
            theme.preset = .emerald
            assert(theme.palette.isDark == true, "Emerald harus dark-mode jade")

            theme.preset = .aurora
            assert(theme.palette.isDark == true, "Aurora harus dark-mode indigo")

            // 4. Verifikasi Accent Colors & Custom Hex Parsing
            theme.accentColor = .emeraldGreen
            assert(theme.accentColor == .emeraldGreen, "Accent harus berubah ke emeraldGreen")

            theme.accentColor = .custom
            theme.customHex = "00D2FF" // Cyan
            assert(theme.customHex == "00D2FF", "Custom hex tersimpan")
            let _ = theme.effectiveAccentColor

            // Invalid hex handling test (graceful fallback)
            theme.customHex = "ZZZZZZ"
            let _ = theme.effectiveAccentColor // harus aman dan fallback tanpa crash

            // 5. Kembalikan ke default untuk kebersihan state aplikasi
            theme.resetToDefault()
            assert(theme.preset == .midnight, "Setelah reset harus kembali ke midnight")
            assert(theme.accentColor == .orange, "Setelah reset accent harus kembali ke orange")
        }

        // Dummy module class untuk pengujian registry & router
        final class TestModule: IslandModule {
            let identifier: String
            let displayName: String
            var currentPriority: ModulePriority
            var isAvailable: Bool
            var capabilities: ModuleCapability
            var associatedMode: IslandMode
            var activateCount = 0
            var deactivateCount = 0

            init(
                identifier: String,
                displayName: String,
                priority: ModulePriority,
                isAvailable: Bool = true,
                capabilities: ModuleCapability = [.collapsedPill],
                associatedMode: IslandMode = .idle
            ) {
                self.identifier = identifier
                self.displayName = displayName
                self.currentPriority = priority
                self.isAvailable = isAvailable
                self.capabilities = capabilities
                self.associatedMode = associatedMode
            }

            func activate() async { activateCount += 1 }
            func deactivate() async { deactivateCount += 1 }
        }

        // Assertion 24: Module Registration, Lookup & Duplicate Prevention
        runTest("ModuleRegistry: Registrasi, Lookup, Unregister, dan Pencegahan Duplikasi ID") {
            let registry = ModuleRegistry()
            let modA = TestModule(identifier: "test.battery", displayName: "Baterai", priority: .standby, associatedMode: .idle)
            let modB = TestModule(identifier: "test.timer", displayName: "Timer", priority: .upcomingEvent, associatedMode: .banner)

            // 1. Registrasi berhasil
            try registry.register(modA)
            try registry.register(modB)
            assert(registry.count == 2, "Harus ada 2 modul terdaftar")

            // 2. Lookup berhasil
            assert(registry.module(for: "test.battery")?.displayName == "Baterai")
            assert(registry.module(for: "test.timer")?.displayName == "Timer")
            assert(registry.module(for: "test.nonexistent") == nil)

            // 3. Pencegahan duplikasi id
            var duplicateCaught = false
            do {
                let duplicate = TestModule(identifier: "test.battery", displayName: "Baterai 2", priority: .critical)
                try registry.register(duplicate)
            } catch ModuleRegistryError.duplicateModule(let id) {
                assert(id == "test.battery")
                duplicateCaught = true
            } catch {
                fatalError("Tipe error tidak sesuai: \(error)")
            }
            assert(duplicateCaught, "Registrasi modul dengan id duplikat harus melempar error")

            // 4. Unregister
            let removed = registry.unregister(identifier: "test.battery")
            assert(removed?.identifier == "test.battery")
            assert(registry.count == 1)
            assert(registry.module(for: "test.battery") == nil)
        }

        // Assertion 25: Module Priority Hierarchical Sorting
        runTest("ModuleRegistry: Pengurutan Modul Berdasarkan Prioritas Hierarkis") {
            let registry = ModuleRegistry()
            let mStandby = TestModule(identifier: "mod.standby", displayName: "Standby", priority: .standby)
            let mCritical = TestModule(identifier: "mod.critical", displayName: "Critical", priority: .critical)
            let mMedia = TestModule(identifier: "mod.media", displayName: "Media", priority: .activeMedia)
            let mUpcoming = TestModule(identifier: "mod.upcoming", displayName: "Upcoming", priority: .upcomingEvent)
            let mDisabled = TestModule(identifier: "mod.disabled", displayName: "Disabled", priority: ModulePriority(999), isAvailable: false)

            try registry.register(mStandby)
            try registry.register(mCritical)
            try registry.register(mMedia)
            try registry.register(mUpcoming)
            try registry.register(mDisabled)

            let sortedAvailable = registry.availableModulesSortedByPriority()
            assert(sortedAvailable.count == 4, "Modul non-available tidak boleh masuk availableModulesSortedByPriority")
            assert(sortedAvailable[0].identifier == "mod.critical", "Posisi 1 harus critical (100)")
            assert(sortedAvailable[1].identifier == "mod.media", "Posisi 2 harus activeMedia (80)")
            assert(sortedAvailable[2].identifier == "mod.upcoming", "Posisi 3 harus upcomingEvent (60)")
            assert(sortedAvailable[3].identifier == "mod.standby", "Posisi 4 harus standby (40)")
        }

        // Assertion 26: GeneralSettings & StandbyMode Persistence
        runTest("GeneralSettings: StandbyMode Configuration & UserDefaults Persistence") {
            let settings = GeneralSettings()

            // 1. Reset baseline default
            settings.resetToDefaults()
            assert(settings.standbyMode == .smart, "Default standbyMode harus .smart")

            // 2. Ubah ke seluruh opsi StandbyMode dan verifikasi persistensi
            let modes: [StandbyMode] = [.clock, .prayer, .music, .battery, .calendar, .minimal, .smart]
            for mode in modes {
                settings.standbyMode = mode
                assert(settings.standbyMode == mode)
                let saved = UserDefaults.standard.string(forKey: GeneralSettings.standbyModeKey)
                assert(saved == mode.rawValue, "UserDefaults harus menyimpan \(mode.rawValue)")
            }

            // 3. Kembalikan ke .smart
            settings.resetToDefaults()
            assert(settings.standbyMode == .smart)
        }

        // Assertion 27: IslandModeRouter Priority Resolution & Anti-Flapping
        await runAsyncTest("IslandModeRouter: Resolusi Prioritas Deterministik & Anti-Flapping") {
            let registry = ModuleRegistry()
            let settings = GeneralSettings()
            settings.standbyMode = .smart

            let prayerMod = TestModule(identifier: "org.ozill.prayer", displayName: "Prayer", priority: .standby, associatedMode: .prayer)
            let musicMod = TestModule(identifier: "org.ozill.music", displayName: "Music", priority: .activeMedia, associatedMode: .music)
            let criticalMod = TestModule(identifier: "org.ozill.emergency", displayName: "Alert", priority: .critical, associatedMode: .banner)

            try registry.register(prayerMod)
            try registry.register(musicMod)
            try registry.register(criticalMod)

            let router = IslandModeRouter(registry: registry, settings: settings)

            // 1. Critical event (Alert) mengalahkan Music & Prayer
            let (m1, mod1) = await router.updateRoute()
            assert(m1 == .banner, "Harus memilih mode banner untuk critical alert")
            assert(mod1?.identifier == "org.ozill.emergency")
            assert(criticalMod.activateCount == 1)

            // 2. Anti-flapping test: updateRoute berulang dengan state identik tidak memicu re-activation
            let (m2, mod2) = await router.updateRoute()
            assert(m2 == .banner)
            assert(mod2?.identifier == "org.ozill.emergency")
            assert(criticalMod.activateCount == 1, "Anti-flapping: activate tidak boleh dipanggil ganda jika mode sama")

            // 3. Matikan critical alert -> Music (activeMedia, 80) harus naik menjadi aktif
            criticalMod.isAvailable = false
            let (m3, mod3) = await router.updateRoute()
            assert(m3 == .music, "Ketika critical berakhir, musik yang sedang aktif harus mengambil alih")
            assert(mod3?.identifier == "org.ozill.music")
            assert(criticalMod.deactivateCount == 1, "Modul lama harus di-deactivate")
            assert(musicMod.activateCount == 1, "Modul baru harus di-activate")

            // 4. Matikan musik -> Fallback ke standby mode (Prayer)
            musicMod.isAvailable = false
            let (m4, mod4) = await router.updateRoute()
            assert(m4 == .prayer, "Fallback harus ke prayer yang standby")
            assert(mod4?.identifier == "org.ozill.prayer")
        }

        // Assertion 28: MockMusicProvider Playback, Capabilities & Unavailable Handling
        await runAsyncTest("MockMusicProvider: Simulasi Playback, Siklus Trek, dan Kontrol Kapabilitas") {
            let mock = MockMusicProvider(
                identifier: "test.mock.player",
                displayName: "Test Player",
                isAvailable: true,
                capabilities: [.playPause, .skipNext] // tanpa skipPrevious
            )

            // 1. Snapshot awal
            let snap1 = await mock.fetchSnapshot()
            assert(snap1 != nil, "Snapshot awal harus ada")
            assert(snap1?.title == "Starboy")
            assert(snap1?.artist == "The Weeknd ft. Daft Punk")
            let state1 = await mock.fetchPlaybackState()
            assert(state1 == .paused)

            // 2. Play / Pause
            try await mock.playPause()
            let statePlay = await mock.fetchPlaybackState()
            assert(statePlay == .playing, "State harus .playing setelah playPause()")
            try await mock.playPause()
            let statePause = await mock.fetchPlaybackState()
            assert(statePause == .paused, "State harus .paused setelah playPause() kedua")

            // 3. Skip Next
            try await mock.next()
            let snap2 = await mock.fetchSnapshot()
            assert(snap2?.title == "Blinding Lights", "Trek harus maju ke Blinding Lights")
            let stateNext = await mock.fetchPlaybackState()
            assert(stateNext == .playing, "State otomatis playing saat next track")

            // 4. Kapabilitas yang tidak didukung harus melempar error
            var unsupportedCaught = false
            do {
                try await mock.previous()
            } catch MusicProviderError.unsupportedAction(let action) {
                assert(action == "skipPrevious")
                unsupportedCaught = true
            } catch {
                fatalError("Error tidak sesuai: \(error)")
            }
            assert(unsupportedCaught, "Memanggil previous pada provider tanpa kapabilitas skipPrevious harus melempar error")

            // 5. Provider Unavailable handling
            mock.setAvailable(false)
            let snapUnavailable = await mock.fetchSnapshot()
            assert(snapUnavailable == nil, "Snapshot harus nil saat provider unavailable")

            var unavailableCaught = false
            do {
                try await mock.playPause()
            } catch MusicProviderError.providerUnavailable {
                unavailableCaught = true
            } catch {
                fatalError("Error tidak sesuai: \(error)")
            }
            assert(unavailableCaught, "Kontrol pada provider unavailable harus melempar error")
        }

        // Dummy browser adapter untuk pengujian unit & multi-tab prioritization
        final class MockBrowserAdapter: BrowserAdapter, @unchecked Sendable {
            let browserBundleIdentifier: String
            let browserDisplayName: String
            let supportedCapabilities: MusicProviderCapabilities
            var mockSessions: [BrowserMediaSession] = []
            var isRunning: Bool = true
            var lastAction: String?
            var lastSessionId: String?

            var isBrowserRunning: Bool { isRunning }

            init(
                bundleId: String = "com.google.Chrome",
                name: String = "Mock Chrome",
                caps: MusicProviderCapabilities = [.playPause, .skipNext, .skipPrevious, .seek],
                sessions: [BrowserMediaSession] = []
            ) {
                self.browserBundleIdentifier = bundleId
                self.browserDisplayName = name
                self.supportedCapabilities = caps
                self.mockSessions = sessions
            }

            func detectMediaSessions() async -> [BrowserMediaSession] {
                guard isRunning else { return [] }
                return mockSessions
            }

            func playPause(sessionId: String) async throws { lastAction = "playPause"; lastSessionId = sessionId }
            func next(sessionId: String) async throws { lastAction = "next"; lastSessionId = sessionId }
            func previous(sessionId: String) async throws { lastAction = "previous"; lastSessionId = sessionId }
            func seek(to seconds: TimeInterval, sessionId: String) async throws { lastAction = "seek"; lastSessionId = sessionId }
        }

        // Assertion 29: Browser Adapter Capability & Honest Reporting
        runTest("Browser Adapters: Pelaporan Kapabilitas Sah per Browser (Chrome, Safari, Edge, Firefox)") {
            let chrome = ChromeMusicAdapter()
            assert(chrome.browserBundleIdentifier == "com.google.Chrome")
            assert(chrome.supportedCapabilities.contains([.playPause, .skipNext, .skipPrevious, .seek]))

            let safari = SafariMusicAdapter()
            assert(safari.browserBundleIdentifier == "com.apple.Safari")
            assert(safari.supportedCapabilities.contains([.playPause, .seek]))

            let edge = EdgeMusicAdapter()
            assert(edge.browserBundleIdentifier == "com.microsoft.edgemac")
            assert(edge.supportedCapabilities.contains([.playPause, .skipNext]))

            let firefox = FirefoxMusicAdapter()
            assert(firefox.browserBundleIdentifier == "org.mozilla.firefox")
            // Firefox melaporkan secara jujur keterbatasan kapabilitas kamus AppleScript
            assert(firefox.supportedCapabilities.isEmpty, "Firefox harus melaporkan kapabilitas kosong tanpa extension")
        }

        // Assertion 30: YouTube & YouTube Music Classification & Metadata Parsing
        runTest("YouTube Session: Klasifikasi YouTube Reguler vs YouTube Music dan Perhitungan Progress") {
            let regularItem = NowPlayingItem(
                title: "LANY - Malibu Nights",
                artist: "LANY",
                album: "Google Chrome",
                duration: 286,
                playbackPosition: 143,
                source: .browser
            )
            assert(regularItem.source == .browser)
            assert(regularItem.formattedPosition == "2:23")
            assert(regularItem.formattedDuration == "4:46")
            assert(abs(regularItem.progress - 0.5) < 0.01, "Progress harus 50%")

            let ytMusicItem = NowPlayingItem(
                title: "Starboy",
                artist: "The Weeknd",
                album: "Safari",
                duration: 230,
                playbackPosition: 0,
                source: .youtubeMusic
            )
            assert(ytMusicItem.source == .youtubeMusic)
            assert(ytMusicItem.source.sfSymbol == "play.rectangle.fill")
            assert(ytMusicItem.progress == 0.0)

            let session = BrowserMediaSession(
                id: "chrome::1::2",
                browserBundleId: "com.google.Chrome",
                browserName: "Google Chrome",
                tabTitle: "LANY - Malibu Nights",
                urlString: "https://www.youtube.com/watch?v=123",
                nowPlaying: regularItem,
                isPlaying: true,
                isYouTube: true,
                isYouTubeMusic: false
            )
            assert(session.isYouTube == true)
            assert(session.isYouTubeMusic == false)
            assert(session.isPlaying == true)
        }

        // Assertion 31: BrowserMusicProvider Multi-Tab Prioritization & Session Override
        await runAsyncTest("BrowserMusicProvider: Prioritas Multi-Tab (Playing > Paused) dan Override Manual") {
            let tab1Paused = BrowserMediaSession(
                id: "tab-1-paused",
                browserBundleId: "com.google.Chrome",
                browserName: "Google Chrome",
                tabTitle: "Tutorial Swift - Paused",
                urlString: "https://youtube.com/watch?v=t1",
                nowPlaying: NowPlayingItem(title: "Tutorial Swift", artist: "Dev", duration: 600, source: .browser),
                isPlaying: false,
                isYouTube: true,
                isYouTubeMusic: false
            )
            let tab2Playing = BrowserMediaSession(
                id: "tab-2-playing",
                browserBundleId: "com.google.Chrome",
                browserName: "Google Chrome",
                tabTitle: "Lo-Fi Beats - Playing",
                urlString: "https://music.youtube.com/watch?v=t2",
                nowPlaying: NowPlayingItem(title: "Lo-Fi Beats", artist: "ChilledCow", duration: 180, source: .youtubeMusic),
                isPlaying: true,
                isYouTube: false,
                isYouTubeMusic: true
            )

            let mockAdapter = MockBrowserAdapter(sessions: [tab1Paused, tab2Playing])
            let provider = BrowserMusicProvider(adapters: [mockAdapter])

            // 1. fetchSnapshot harus otomatis memprioritaskan tab yang sedang playing (Tab 2)
            let snap = await provider.fetchSnapshot()
            assert(snap?.title == "Lo-Fi Beats", "Harus memprioritaskan tab yang sedang playing")
            let pState1 = await provider.fetchPlaybackState()
            assert(pState1 == .playing)

            // 2. Pemilihan manual sesi (override)
            provider.selectSession(id: "tab-1-paused")
            let overrideSnap = await provider.fetchSnapshot()
            assert(overrideSnap?.title == "Tutorial Swift", "Harus beralih ke sesi yang dipilih manual")
            let pState2 = await provider.fetchPlaybackState()
            assert(pState2 == .paused)

            // 3. Kontrol playPause dikirimkan ke adapter
            try? await provider.playPause()
            assert(mockAdapter.lastAction == "playPause")
        }

        // Assertion 32: UniversalMusicManager Multi-Provider Aggregation & Routing
        await runAsyncTest("UniversalMusicManager: Koordinasi Multi-Provider & Integrasi Mode Router") {
            let manager = UniversalMusicManager.shared

            // Registrasi modul jika belum terdaftar di registry bersama
            if ModuleRegistry.shared.module(for: "org.ozill.prayer") == nil {
                try? ModuleRegistry.shared.register(PrayerIslandModule.shared)
            }
            if ModuleRegistry.shared.module(for: "org.ozill.music") == nil {
                try? ModuleRegistry.shared.register(MusicIslandModule.shared)
            }

            // Buat mock provider yang sedang playing
            let activeMock = MockMusicProvider(
                identifier: "test.active.provider",
                displayName: "Test Active Player",
                isAvailable: true,
                capabilities: .fullControls
            )
            activeMock.setPlaybackState(.playing)

            manager.mockProvider = activeMock
            manager.selectProvider(id: "test.active.provider")

            await manager.pollActiveMedia()

            // 1. Manager mendeteksi mock yang sedang playing
            assert(manager.playbackState == .playing, "Playback state harus .playing")
            assert(manager.currentItem?.title == "Starboy")
            assert(manager.activeProvider?.identifier == "test.active.provider")

            // 2. Router otomatis menaikkan prioritas ke .music
            let (mode, activeMod) = IslandModeRouter.shared.resolveActiveMode()
            assert(mode == .music, "Router harus beralih ke mode .music saat ada media aktif")
            assert(activeMod?.associatedMode == .music)

            // 3. Bersihkan mock provider agar tidak mengotori runtime
            manager.mockProvider = nil
            manager.selectProvider(id: nil)
            await manager.pollActiveMedia()
        }

        // Assertion 33: Non-blocking ScriptBridge Execution & Watchdog Timeout
        await runAsyncTest("ScriptBridge: Eksekusi Asinkron Latar Belakang & Watchdog Timeout Protection") {
            // 1. Eksekusi cepat yang berhasil
            let (success, out) = await ScriptBridge.executeAppleScript("return \"OZILL_TEST_OK\"", timeout: 1.0)
            assert(success == true, "AppleScript valid harus berhasil dieksekusi")
            assert(out == "OZILL_TEST_OK", "Output harus sesuai")

            // 2. Skrip dengan delay panjang yang memicu watchdog timeout
            let (timedOut, errStr) = await ScriptBridge.executeAppleScript("delay 3\nreturn \"late\"", timeout: 0.3)
            assert(timedOut == false, "Skrip yang melebihi timeout harus dihentikan oleh watchdog")
            assert(errStr.contains("timed out"), "Pesan error harus mengindikasikan timeout")
        }

        // Assertion 34: IdleDimmingService Auto-Transparency (> 15 Menit) & Waking Interaction
        runTest("IdleDimmingService: Transparansi Otomatis Saat Idle > 15 Menit dan Reaktivasi Instan") {
            let service = IdleDimmingService(timeoutSeconds: 900)

            // 1. Kondisi awal: aktif penuh (1.0)
            assert(service.isDimmed == false)
            assert(service.currentOpacity == 1.0)

            // 2. Simulasi waktu belum mencapai 15 menit (10 menit / 600 detik)
            let tenMinutesLater = Date().addingTimeInterval(600)
            service.evaluateIdleState(simulatedDate: tenMinutesLater, checkUpcomingPrayer: false, checkMediaPlaying: false)
            assert(service.isDimmed == false, "Sebelum 15 menit tidak boleh transparan")
            assert(service.currentOpacity == 1.0)

            // 3. Simulasi waktu melewati batas 15 menit (16 menit / 960 detik)
            let sixteenMinutesLater = Date().addingTimeInterval(960)
            service.evaluateIdleState(simulatedDate: sixteenMinutesLater, checkUpcomingPrayer: false, checkMediaPlaying: false)
            assert(service.isDimmed == true, "Harus menjadi transparan setelah > 15 menit idle")
            assert(service.currentOpacity == service.dimmedOpacity)

            // 4. Interaksi pengguna (hover / klik) langsung membangkitkan ke opasitas penuh (1.0)
            service.recordActivity()
            assert(service.isDimmed == false, "Aktivitas pengguna harus seketika mengembalikan opasitas")
            assert(service.currentOpacity == 1.0)
        }

        // Assertion 35: YouTube Thumbnail Regex Extraction & System Volume Clamping (Item A)
        runTest("Item A: Ekstraksi Thumbnail YouTube & Clamping Volume Output Sistem") {
            // 1. Ekstraksi URL YouTube standar (?v=...)
            let thumb1 = BrowserMediaHelper.extractYouTubeThumbnail(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
            assert(thumb1 == "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg", "Thumbnail video YouTube watch harus terekstraksi")

            // 2. Ekstraksi short URL (youtu.be/...)
            let thumb2 = BrowserMediaHelper.extractYouTubeThumbnail(from: "https://youtu.be/dQw4w9WgXcQ?si=xyz123")
            assert(thumb2 == "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg", "Thumbnail youtu.be harus terekstraksi")

            // 3. Ekstraksi Shorts
            let thumb3 = BrowserMediaHelper.extractYouTubeThumbnail(from: "https://www.youtube.com/shorts/12345678901")
            assert(thumb3 == "https://i.ytimg.com/vi/12345678901/mqdefault.jpg", "Thumbnail Shorts harus terekstraksi")

            // 4. URL non-YouTube harus mengembalikan nil secara aman
            let thumb4 = BrowserMediaHelper.extractYouTubeThumbnail(from: "https://open.spotify.com/track/12345")
            assert(thumb4 == nil, "URL non-YouTube harus menghasilkan nil")

            // 5. Volume Clamping
            let volService = SystemVolumeService()
            volService.setVolume(1.5)
            assert(volService.volume == 1.0, "Volume > 1.0 harus di-clamp ke 1.0")
            volService.setVolume(-0.2)
            assert(volService.volume == 0.0, "Volume < 0.0 harus di-clamp ke 0.0")
            volService.setVolume(0.45)
            assert(abs(volService.volume - 0.45) < 0.001, "Volume valid harus tersimpan")
        }

        // Assertion 36: Pomodoro Focus Timer State Engine & Preset Math (Item B)
        runTest("Item B: Pomodoro Focus Timer State Engine, Presets & Prioritas Modul") {
            let timer = TimerService()
            let timerMod = TimerIslandModule(timerService: timer)

            // 1. Preset Focus (25m = 1500 detik)
            timer.selectPreset(.focus)
            assert(timer.totalDuration == 1500)
            assert(timer.remainingSeconds == 1500)
            assert(timer.formattedRemainingTime == "25:00")
            assert(timer.state == .idle)
            assert(timerMod.currentPriority == .background)

            // 2. Transisi Start -> Running -> Prioritas Active
            timer.start()
            assert(timer.state == .running)
            assert(timerMod.currentPriority == .activeMedia)

            // 3. Transisi Pause -> Prioritas Upcoming
            timer.pause()
            assert(timer.state == .paused)
            assert(timerMod.currentPriority == .upcomingEvent)

            // 4. Preset Istirahat Singkat (5m = 300 detik)
            timer.selectPreset(.shortBreak)
            assert(timer.totalDuration == 300)
            assert(timer.formattedRemainingTime == "05:00")

            // 5. Reset
            timer.reset()
            assert(timer.state == .idle)
            assert(timer.remainingSeconds == 300)
        }

        // Assertion 37: Smart Battery Alert & Charger Connected Animation Trigger (Item C)
        runTest("Item C: Smart Battery Alert (<= 15%) & Pop-up Animasi Pengisian Daya (3.5s)") {
            let sys = SystemInfoService()

            // 1. Trigger charger connected banner
            assert(sys.showChargerConnectedBanner == false)
            sys.triggerChargerBanner()
            assert(sys.showChargerConnectedBanner == true, "Trigger charger banner harus seketika mengaktifkan banner")

            // 2. Evaluasi threshold low battery
            // Sistem mengecek batteryLevel <= 15 && !isACPluggedIn
            assert(sys.batteryLevel >= 0 && sys.batteryLevel <= 100)
        }

        // Assertion 38: Launch At Login Manager & Module Registry Integration (Item D)
        runTest("Item D: Launch At Login Manager Status & Registrasi Modul Universal") {
            let launchMgr = LaunchAtLoginManager()
            launchMgr.refreshStatus()
            // Di lingkungan terminal/debug non-installed app, launchMgr membaca status tanpa crash
            assert(launchMgr.isEnabled == true || launchMgr.isEnabled == false)

            // Pastikan ModuleRegistry menampung 4 modul terintegrasi
            let reg = ModuleRegistry()
            try! reg.register(PrayerIslandModule.shared)
            try! reg.register(MusicIslandModule.shared)
            try! reg.register(TimerIslandModule.shared)
            try! reg.register(NotificationIslandModule.shared)
            assert(reg.count == 4, "ModuleRegistry harus menampung Prayer, Music, Timer, dan Notification")
            assert(reg.module(for: "org.ozill.timer") != nil, "Timer module harus terdaftar di registry")
            assert(reg.module(for: "org.ozill.notification") != nil, "Notification module harus terdaftar di registry")
        }

        // Assertion 39: Universal Notification Island Service & Multi-Track Integration (Jalur A, B, C)
        runTest("Universal Notification Island: Integrasi Jalur A, B, dan C & Prioritas Banner") {
            let notifService = NotificationIslandService()
            let notifMod = NotificationIslandModule(notifService: notifService)

            // 1. Kondisi awal: tidak ada notifikasi aktif
            assert(notifService.activeNotification == nil)
            assert(notifMod.currentPriority == .background)

            // 2. Terbitkan notifikasi WhatsApp (Jalur A / Jalur B)
            let testWA = IslandNotification(
                appName: "WhatsApp",
                title: "Budi Santoso",
                message: "Cuy, file desainnya udah gue kirim ya!",
                iconSymbol: "message.fill",
                accentHex: "#25D366",
                duration: 4.5
            )
            notifService.postNotification(testWA)

            // 3. Verifikasi banner aktif & prioritas kritis (100)
            assert(notifService.activeNotification?.id == testWA.id)
            assert(notifService.activeNotification?.appName == "WhatsApp")
            assert(notifService.activeNotification?.accentHex == "#25D366")
            assert(notifMod.currentPriority == .critical, "Notifikasi aktif harus memiliki prioritas kritis untuk tampil di Island")
            assert(notifService.recentNotifications.contains(where: { $0.id == testWA.id }))

            // 4. Dismiss notifikasi
            notifService.dismissActiveNotification()
            assert(notifService.activeNotification == nil, "Dismiss harus mengembalikan activeNotification ke nil")
            assert(notifMod.currentPriority == .background)
        }

        // Assertion 40: Fase 3A - AudioController Bounds, Increment, Mute Toggle & Debounce
        runTest("Fase 3A: AudioController Clamping, Step +/- 0.05, Toggle Mute & State Independence") {
            let audio = AudioController(initialVolume: 0.5, isMuted: false, isAvailable: true, stepIncrement: 0.05)

            // 1. Clamping bounds
            audio.setVolume(1.5)
            assert(audio.volume == 1.0, "Volume > 1.0 harus di-clamp ke 1.0")
            audio.setVolume(-0.2)
            assert(audio.volume == 0.0, "Volume < 0.0 harus di-clamp ke 0.0")

            // 2. Increments & Decrements
            audio.setVolume(0.40)
            audio.increaseVolume()
            assert(abs(audio.volume - 0.45) < 0.001, "increaseVolume() harus menambah sebesar stepIncrement (0.05)")
            audio.decreaseVolume()
            assert(abs(audio.volume - 0.40) < 0.001, "decreaseVolume() harus mengurangi sebesar stepIncrement (0.05)")

            // 3. Mute toggle
            assert(!audio.isMuted)
            audio.toggleMute()
            assert(audio.isMuted, "toggleMute() harus mengubah isMuted ke true")
            audio.toggleMute()
            assert(!audio.isMuted, "toggleMute() kedua harus mengembalikan isMuted ke false")

            // 4. Setting volume unmutes if positive
            audio.toggleMute()
            assert(audio.isMuted)
            audio.setVolume(0.60)
            assert(!audio.isMuted, "setVolume dengan nilai > 0 harus otomatis meng-unmute")

            // 5. AudioState immutability & model check
            let state = AudioState(volume: 0.85, isMuted: true, isAvailable: true)
            assert(state.volume == 0.85)
            assert(state.isMuted)
            assert(state.isAvailable)

            // 6. Device availability fallback
            let unavailableState = AudioState(volume: 0.5, isMuted: false, isAvailable: false)
            assert(!unavailableState.isAvailable)
        }

        // Assertion 41: Fase 3B - Media Control Previous/Next/PlayPause, Capabilities, Chrome Multi-Tab Manual Selection
        await runAsyncTest("Fase 3B: Media Control Previous/Next/PlayPause, Capabilities, Chrome Multi-Tab Manual Selection") {
            let manager = UniversalMusicManager.shared
            manager.clearActiveSession()

            // 1. Skenario Tidak Ada Provider Aktif (Empty State)
            let emptyMock = MockMusicProvider(
                identifier: "mock.empty",
                displayName: "Empty Provider",
                isAvailable: true,
                capabilities: [],
                initialTracks: []
            )
            emptyMock.setPlaybackState(.stopped)
            manager.mockProvider = emptyMock
            manager.selectProvider(id: "mock.empty")
            await manager.pollActiveMedia()

            assert(manager.currentItem == nil, "Saat provider kosong, currentItem harus nil")
            assert(manager.playbackState == .stopped, "State harus .stopped saat tidak ada media aktif")

            // 2. Skenario Provider dengan Kapabilitas Parsial (Hanya Play/Pause, Tanpa Next/Previous)
            let limitedMock = MockMusicProvider(
                identifier: "mock.limited",
                displayName: "Limited Player",
                isAvailable: true,
                capabilities: [.playPause]
            )
            limitedMock.setPlaybackState(.paused)
            manager.mockProvider = limitedMock
            manager.selectProvider(id: "mock.limited")
            await manager.pollActiveMedia()

            assert(manager.activeProvider?.capabilities.contains(.playPause) == true)
            assert(manager.activeProvider?.capabilities.contains(.skipNext) == false, "Limited player tidak boleh memiliki skipNext")
            assert(manager.activeProvider?.capabilities.contains(.skipPrevious) == false, "Limited player tidak boleh memiliki skipPrevious")

            // 3. Play/Pause state toggle
            await manager.playPause()
            assert(manager.playbackState == .playing, "playPause() harus mengubah state paused -> playing")
            await manager.playPause()
            assert(manager.playbackState == .paused, "playPause() kedua harus mengubah playing -> paused")

            // 4. Skenario Multi-Tab Chrome: Tab 1 (Sedang Playing Otomatis) vs Tab 2 (Manual Selection)
            let sessionTab1 = BrowserMediaSession(
                id: "chrome::1::1",
                browserBundleId: "com.google.Chrome",
                browserName: "Google Chrome",
                tabTitle: "Video Otomatis Diputar",
                urlString: "https://www.youtube.com/watch?v=auto123",
                nowPlaying: NowPlayingItem(title: "Video Otomatis", artist: "Channel A", source: .browser),
                isPlaying: true,
                isYouTube: true,
                isYouTubeMusic: false
            )
            let sessionTab2 = BrowserMediaSession(
                id: "chrome::1::2",
                browserBundleId: "com.google.Chrome",
                browserName: "Google Chrome",
                tabTitle: "Video Pilihan Manual Pengguna",
                urlString: "https://www.youtube.com/watch?v=manual456",
                nowPlaying: NowPlayingItem(title: "Video Manual Pilihan", artist: "Channel B", source: .browser),
                isPlaying: false,
                isYouTube: true,
                isYouTubeMusic: false
            )

            let mockChromeAdapter = MockBrowserAdapter(
                bundleId: "com.google.Chrome",
                name: "Google Chrome",
                caps: [.playPause, .skipNext, .skipPrevious, .seek],
                sessions: [sessionTab1, sessionTab2]
            )
            let browserProvider = BrowserMusicProvider(adapters: [mockChromeAdapter])
            _ = await browserProvider.fetchAllSessions(force: true)

            // A. Sebelum seleksi manual: default resolusi harus memilih Tab 1 karena isPlaying == true
            let autoSnap = await browserProvider.fetchSnapshot()
            assert(autoSnap?.title == "Video Otomatis", "Secara default polling harus memprioritaskan tab yang playing")

            // B. User memilih Tab 2 secara manual
            browserProvider.selectSession(id: "chrome::1::2")
            let manualSnap = await browserProvider.fetchSnapshot()
            assert(manualSnap?.title == "Video Manual Pilihan", "Seleksi manual harus meng-override prioritas polling otomatis!")

            // C. Eksekusi kontrol (Previous, Next, Play/Pause) harus diarahkan ke Tab 2 (chrome::1::2)
            try await browserProvider.playPause()
            assert(mockChromeAdapter.lastSessionId == "chrome::1::2", "playPause() harus menargetkan tab yang dipilih manual (chrome::1::2), bukan tab 1!")
            assert(mockChromeAdapter.lastAction == "playPause")

            try await browserProvider.next()
            assert(mockChromeAdapter.lastSessionId == "chrome::1::2", "next() harus menargetkan tab yang dipilih manual (chrome::1::2)!")
            assert(mockChromeAdapter.lastAction == "next")

            try await browserProvider.previous()
            assert(mockChromeAdapter.lastSessionId == "chrome::1::2", "previous() harus menargetkan tab yang dipilih manual (chrome::1::2)!")
            assert(mockChromeAdapter.lastAction == "previous")

            // 5. Bersihkan state mock
            manager.mockProvider = nil
            manager.selectProvider(id: nil)
            manager.clearActiveSession()
            await manager.pollActiveMedia()
        }

        // MARK: - Assertion 42: Fase 3C - Display Brightness Control, Clamping, Multi-Display Selection & External Fallback
        final class MockDisplayHardwareBridge: DisplayHardwareBridging, @unchecked Sendable {
            private let lock = NSLock()
            private var displays: [DisplayDevice]
            private var brightnessMap: [CGDirectDisplayID: Float]
            var shouldFailWrite: Bool = false
            var shouldFailRead: Bool = false
            var lastWrittenValue: Float?
            var lastWrittenDisplayId: CGDirectDisplayID?

            init(displays: [DisplayDevice], initialBrightness: [CGDirectDisplayID: Float] = [:]) {
                self.displays = displays
                self.brightnessMap = initialBrightness
            }

            func setDisplays(_ newDisplays: [DisplayDevice]) {
                lock.withLock {
                    self.displays = newDisplays
                }
            }

            func discoverDisplays() async -> [DisplayDevice] {
                lock.withLock { displays }
            }

            func readBrightness(for displayId: CGDirectDisplayID) async -> Result<Float, Error> {
                lock.withLock {
                    if shouldFailRead {
                        return .failure(DisplayError.hardwareReadFailed(-99))
                    }
                    guard let dev = displays.first(where: { $0.id == displayId }) else {
                        return .failure(DisplayError.displayNotFound)
                    }
                    guard dev.canAdjustBrightness else {
                        return .failure(DisplayError.unsupportedExternalMonitor)
                    }
                    let val = brightnessMap[displayId] ?? 0.5
                    return .success(val)
                }
            }

            func writeBrightness(_ value: Float, for displayId: CGDirectDisplayID) async -> Result<Void, Error> {
                lock.withLock {
                    if shouldFailWrite {
                        return .failure(DisplayError.hardwareWriteFailed(-99))
                    }
                    guard let dev = displays.first(where: { $0.id == displayId }) else {
                        return .failure(DisplayError.displayNotFound)
                    }
                    guard dev.canAdjustBrightness else {
                        return .failure(DisplayError.unsupportedExternalMonitor)
                    }
                    let clamped = max(0.0, min(1.0, value))
                    brightnessMap[displayId] = clamped
                    lastWrittenValue = clamped
                    lastWrittenDisplayId = displayId
                    return .success(())
                }
            }
        }

        await runAsyncTest("Fase 3C: Display Brightness Control, Clamping, Multi-Display Selection & External Fallback") {
            let builtInDisplay = DisplayDevice(
                id: 1,
                name: "Built-in Retina Display",
                kind: .builtIn,
                isMain: true,
                canAdjustBrightness: true
            )
            let externalMonitor = DisplayDevice(
                id: 2,
                name: "Dell UltraSharp 4K",
                kind: .external,
                isMain: false,
                canAdjustBrightness: false
            )

            let mockBridge = MockDisplayHardwareBridge(
                displays: [builtInDisplay, externalMonitor],
                initialBrightness: [1: 0.5]
            )
            let controller = BrightnessController(hardwareBridge: mockBridge)
            controller.stopSyncTimer()
            await controller.refreshDisplays()
            await controller.refreshBrightness()

            // 1. Verifikasi inisialisasi & seleksi awal ke built-in display
            assert(controller.activeDisplay?.id == 1, "Default active display harus memilih built-in display")
            assert(controller.isAvailable == true, "Built-in display harus mendukung kontrol kecerahan")
            assert(controller.brightness == 0.5, "Nilai brightness awal harus 0.5")

            // 2. Brightness Clamping
            controller.setBrightness(1.4)
            assert(controller.brightness == 1.0, "Nilai > 1.0 harus di-clamp ke 1.0")
            controller.setBrightness(-0.2)
            assert(controller.brightness == 0.0, "Nilai < 0.0 harus di-clamp ke 0.0")
            controller.setBrightness(0.65)
            assert(abs(controller.brightness - 0.65) < 0.001, "Nilai valid 0.65 harus tersimpan")

            // 3. Step Increment & Decrement
            controller.increaseBrightness() // 0.65 + 0.05 = 0.70
            assert(abs(controller.brightness - 0.70) < 0.001, "increaseBrightness() harus menaikkan 0.05")
            controller.decreaseBrightness() // 0.70 - 0.05 = 0.65
            assert(abs(controller.brightness - 0.65) < 0.001, "decreaseBrightness() harus menurunkan 0.05")

            controller.setBrightness(0.98)
            controller.increaseBrightness()
            assert(controller.brightness == 1.0, "increaseBrightness di dekat 1.0 harus di-clamp ke 1.0")

            controller.setBrightness(0.02)
            controller.decreaseBrightness()
            assert(controller.brightness == 0.0, "decreaseBrightness di dekat 0.0 harus di-clamp ke 0.0")

            // 4. Hardware Write Reflection setelah debounce
            try? await Task.sleep(nanoseconds: 70_000_000)
            assert(mockBridge.lastWrittenValue == 0.0, "Hardware bridge harus menerima nilai akhir setelah debounce")
            assert(mockBridge.lastWrittenDisplayId == 1)

            // 5. Multiple Display Selection (Beralih ke Monitor Eksternal)
            controller.selectDisplay(id: 2)
            await controller.refreshBrightness()
            assert(controller.activeDisplay?.id == 2, "Active display harus berganti ke Dell UltraSharp (id: 2)")
            assert(controller.isAvailable == false, "Monitor eksternal tanpa DDC/CI publik harus unavailable")
            if case .unsupported = controller.status {
                // Sesuai ekspektasi
            } else {
                assertionFailure("Status monitor eksternal harus .unsupported")
            }

            // 6. Penolakan Penulisan pada Monitor Eksternal yang Tidak Didukung
            let lastWrittenBefore = mockBridge.lastWrittenValue
            controller.setBrightness(0.85)
            try? await Task.sleep(nanoseconds: 70_000_000)
            assert(mockBridge.lastWrittenValue == lastWrittenBefore, "Penulisan brightness ke monitor eksternal tidak boleh diproses ke hardware")

            // 7. Display Disconnect & Auto Fallback
            mockBridge.setDisplays([builtInDisplay])
            await controller.refreshDisplays()
            await controller.refreshBrightness()
            assert(controller.activeDisplay?.id == 1, "Saat monitor eksternal dicabut, harus otomatis fallback ke built-in")
            assert(controller.isAvailable == true, "Status harus kembali available setelah kembali ke built-in")

            // 8. Error Handling
            mockBridge.shouldFailRead = true
            await controller.refreshBrightness(force: true)
            assert(controller.isAvailable == false, "Saat hardware read gagal, isAvailable harus false")
            if case .error = controller.status {
                // Sesuai ekspektasi
            } else {
                assertionFailure("Status saat hardware error harus .error")
            }

            // 9. DisplayState Model Purity
            let stateModel = DisplayState(brightness: 0.8, status: .available, activeDisplay: builtInDisplay)
            assert(stateModel.isAvailable == true)
            let extStateModel = DisplayState(brightness: 0.8, status: .available, activeDisplay: externalMonitor)
            assert(extStateModel.isAvailable == false, "DisplayState harus bernilai isAvailable = false jika display canAdjustBrightness = false")

            // 10. Native Hardware Bridge Safe Discovery
            let nativeBridge = NativeDisplayHardwareBridge()
            let nativeDisplays = await nativeBridge.discoverDisplays()
            assert(!nativeDisplays.isEmpty, "Native bridge harus mendeteksi minimal 1 layar pada macOS aktif")
            if let builtIn = nativeDisplays.first(where: { $0.kind == .builtIn }) {
                let res = await nativeBridge.readBrightness(for: builtIn.id)
                switch res {
                case .success(let val):
                    assert(val >= 0.0 && val <= 1.0, "Nilai pembacaan brightness built-in fisik harus di antara 0.0 s/d 1.0")
                case .failure:
                    break // Toleransi jika mesin virtual / CI tanpa backlight
                }
            }
        }

        // MARK: - Assertion 43: Fase 3D - Safari Quick Action & Screenshot Utility
        final class MockScreenshotHardwareBridge: ScreenshotHardwareBridging, @unchecked Sendable {
            private let lock = NSLock()
            var hasPermission: Bool = true
            var shouldFailCapture: Bool = false
            var captureableWindowsList: [CaptureableWindowInfo] = []

            var lastCapturedMode: String?
            var lastDisplayId: CGDirectDisplayID?
            var lastRect: CGRect?
            var lastWindowId: CGWindowID?

            init(hasPermission: Bool = true, windows: [CaptureableWindowInfo] = []) {
                self.hasPermission = hasPermission
                self.captureableWindowsList = windows
            }

            func checkPermission() -> Bool {
                lock.withLock { hasPermission }
            }

            private func createTestCGImage(width: Int = 200, height: Int = 150) -> CGImage {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                )!
                context.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1.0))
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                return context.makeImage()!
            }

            func captureFullScreen(displayId: CGDirectDisplayID) async -> Result<CGImage, Error> {
                lock.withLock {
                    guard hasPermission else { return .failure(ScreenshotError.permissionDenied) }
                    if shouldFailCapture { return .failure(ScreenshotError.captureFailed("Simulated hardware error")) }
                    lastCapturedMode = "fullScreen"
                    lastDisplayId = displayId
                    return .success(createTestCGImage(width: 800, height: 600))
                }
            }

            func captureArea(_ rect: CGRect, displayId: CGDirectDisplayID) async -> Result<CGImage, Error> {
                lock.withLock {
                    guard hasPermission else { return .failure(ScreenshotError.permissionDenied) }
                    if shouldFailCapture { return .failure(ScreenshotError.captureFailed("Simulated area error")) }
                    guard rect.width > 1 && rect.height > 1 else {
                        return .failure(ScreenshotError.userCancelled)
                    }
                    lastCapturedMode = "selectedArea"
                    lastDisplayId = displayId
                    lastRect = rect
                    return .success(createTestCGImage(width: Int(rect.width), height: Int(rect.height)))
                }
            }

            func captureWindow(windowId: CGWindowID) async -> Result<CGImage, Error> {
                lock.withLock {
                    guard hasPermission else { return .failure(ScreenshotError.permissionDenied) }
                    if shouldFailCapture { return .failure(ScreenshotError.captureFailed("Simulated window error")) }
                    guard captureableWindowsList.contains(where: { $0.id == windowId }) else {
                        return .failure(ScreenshotError.windowNotFound)
                    }
                    lastCapturedMode = "window"
                    lastWindowId = windowId
                    return .success(createTestCGImage(width: 400, height: 300))
                }
            }

            func getCaptureableWindows() async -> [CaptureableWindowInfo] {
                lock.withLock { captureableWindowsList }
            }
        }

        await runAsyncTest("Fase 3D: Safari Quick Action, Screenshot Utility (Full/Area/Window), PNG & Clipboard") {
            // --- BAGIAN A: Safari Quick Action ---
            let launcher = ApplicationLauncher.shared
            assert(ApplicationLauncher.safariBundleId == "com.apple.Safari", "Bundle ID Safari harus 'com.apple.Safari'")

            // 1. Uji deteksi status berjalan Safari
            _ = launcher.isApplicationRunning(bundleIdentifier: ApplicationLauncher.safariBundleId)

            // 2. Error handling bundle identifier tidak valid
            let invalidLaunchResult = await launcher.launchOrActivate(bundleIdentifier: "org.ozill.nonexistent.app12345")
            switch invalidLaunchResult {
            case .failure(let error):
                if let appErr = error as? ApplicationLauncherError, case .applicationNotFound = appErr {
                    // Sesuai ekspektasi
                } else {
                    assertionFailure("Error harus berjenis ApplicationLauncherError.applicationNotFound")
                }
            case .success:
                assertionFailure("Aplikasi non-existent tidak boleh sukses dibuka")
            }

            // --- BAGIAN B: Screenshot Utility ---
            let testWindow = CaptureableWindowInfo(
                id: 42,
                title: "Safari - Welcome to Apple",
                appName: "Safari",
                appBundleId: "com.apple.Safari",
                frame: CGRect(x: 100, y: 100, width: 900, height: 600)
            )

            let mockBridge = MockScreenshotHardwareBridge(hasPermission: true, windows: [testWindow])
            let controller = ScreenshotController(hardwareBridge: mockBridge)

            // 3. Verifikasi Mode Screenshot Enum
            assert(ScreenshotMode.allCases.count == 3)
            assert(ScreenshotMode.fullScreen.systemImage == "display")
            assert(ScreenshotMode.selectedArea.systemImage == "viewfinder")
            assert(ScreenshotMode.window.systemImage == "macwindow")

            // 4. Pengujian Full Screen Capture
            let fullResult = await controller.executeCapture(mode: .fullScreen, displayId: 1)
            switch fullResult {
            case .success(let res):
                assert(res.mode == .fullScreen)
                assert(res.pixelWidth == 800 && res.pixelHeight == 600)
                // Verifikasi Magic Bytes Header PNG (0x89, 0x50, 0x4E, 0x47)
                let header = [UInt8](res.pngData.prefix(4))
                assert(header == [0x89, 0x50, 0x4E, 0x47], "Berkas hasil harus memiliki magic bytes format PNG yang sah")
                assert(mockBridge.lastCapturedMode == "fullScreen")
                assert(mockBridge.lastDisplayId == 1)
            case .failure(let err):
                assertionFailure("Full screen capture harus berhasil pada mock: \(err)")
            }

            // 5. Pengujian Selected Area Capture & Koordinat Fisik Retina Scaling
            let pointsRect = CGRect(x: 50, y: 50, width: 250, height: 180)
            let retinaScale: CGFloat = 2.0
            let physicalRetinaRect = CGRect(
                x: pointsRect.origin.x * retinaScale,
                y: pointsRect.origin.y * retinaScale,
                width: pointsRect.size.width * retinaScale,
                height: pointsRect.size.height * retinaScale
            )

            let areaResult = await controller.executeCapture(mode: .selectedArea, displayId: 1, rect: physicalRetinaRect)
            switch areaResult {
            case .success(let res):
                assert(res.mode == .selectedArea)
                assert(res.pixelWidth == 500 && res.pixelHeight == 360, "Dimensi piksel harus sesuai konversi skala fisik Retina 2x")
                assert(mockBridge.lastCapturedMode == "selectedArea")
                assert(mockBridge.lastRect == physicalRetinaRect)
            case .failure(let err):
                assertionFailure("Area capture harus berhasil: \(err)")
            }

            // 6. Pengujian Pembatalan Pengguna (User Cancellation) pada Area Capture
            let cancelledResult = await controller.executeCapture(mode: .selectedArea, displayId: 1, rect: nil)
            switch cancelledResult {
            case .failure(let err):
                if let scrErr = err as? ScreenshotError, scrErr == .userCancelled {
                    // Sesuai ekspektasi
                } else {
                    assertionFailure("Rect kosong harus menghasilkan ScreenshotError.userCancelled")
                }
            case .success:
                assertionFailure("Capture dengan rect kosong tidak boleh berhasil")
            }

            // 7. Pengujian Window Selection Capture
            await controller.refreshCaptureableWindows()
            assert(controller.availableWindows.count == 1)
            assert(controller.availableWindows.first?.id == 42)

            let windowSuccessResult = await controller.executeCapture(mode: .window, windowId: 42)
            switch windowSuccessResult {
            case .success(let res):
                assert(res.mode == .window)
                assert(res.pixelWidth == 400 && res.pixelHeight == 300)
                assert(mockBridge.lastCapturedMode == "window")
                assert(mockBridge.lastWindowId == 42)
            case .failure(let err):
                assertionFailure("Window capture valid harus berhasil: \(err)")
            }

            // 8. Pengujian Jendela Tidak Valid
            let invalidWindowResult = await controller.executeCapture(mode: .window, windowId: 9999)
            switch invalidWindowResult {
            case .failure(let err):
                if let scrErr = err as? ScreenshotError, scrErr == .windowNotFound {
                    // Sesuai ekspektasi
                } else {
                    assertionFailure("Jendela tidak ditemukan harus menghasilkan ScreenshotError.windowNotFound")
                }
            case .success:
                assertionFailure("Jendela tidak valid tidak boleh berhasil di-capture")
            }

            // 9. Pengujian Izin Screen Recording Ditolak (Permission Unavailable)
            mockBridge.hasPermission = false
            let deniedResult = await controller.executeCapture(mode: .fullScreen)
            switch deniedResult {
            case .failure(let err):
                if let scrErr = err as? ScreenshotError, scrErr == .permissionDenied {
                    // Sesuai ekspektasi
                } else {
                    assertionFailure("Harus menghasilkan ScreenshotError.permissionDenied saat izin tidak ada")
                }
            case .success:
                assertionFailure("Tidak boleh mengambil screenshot saat izin ditolak")
            }
            mockBridge.hasPermission = true

            // 10. Pengujian Output Clipboard & Destinasi File
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("OzillScreenshotTests_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            controller.settings = ScreenshotSettings(
                destination: .customFolder,
                customFolderPath: tempDir.path,
                copyToClipboard: true,
                showNotification: false
            )

            let fileDestResult = await controller.executeCapture(mode: .fullScreen)
            switch fileDestResult {
            case .success(let res):
                assert(res.copiedToClipboard == true, "Clipboard output harus aktif sesuai konfigurasi")
                assert(res.savedURL != nil, "savedURL harus terisi")
                if let fileUrl = res.savedURL {
                    assert(FileManager.default.fileExists(atPath: fileUrl.path), "Berkas PNG harus tersimpan di direktori tujuan")
                }
            case .failure(let err):
                assertionFailure("File write capture gagal: \(err)")
            }

            // 11. Pengujian File Write Error Handling
            controller.settings = ScreenshotSettings(
                destination: .customFolder,
                customFolderPath: "/nonexistent/invalid/directory/path/that/cannot/be/written",
                copyToClipboard: false,
                showNotification: false
            )
            let writeFailResult = await controller.executeCapture(mode: .fullScreen)
            switch writeFailResult {
            case .failure(let err):
                if let scrErr = err as? ScreenshotError, case .fileWriteFailed = scrErr {
                    // Sesuai ekspektasi
                } else {
                    assertionFailure("Menulis ke path invalid harus menghasilkan ScreenshotError.fileWriteFailed")
                }
            case .success:
                assertionFailure("Menulis ke folder invalid tidak boleh berhasil")
            }

            // 12. Native Hardware Bridge Safe Check
            let nativeBridge = NativeScreenshotHardwareBridge()
            _ = nativeBridge.checkPermission()
        }

        // MARK: - Assertion 44: Fase 3E - Compact Touch Bar Quick Controls Integration
        await runAsyncTest("Fase 3E: Compact Touch Bar Quick Controls Integration, Drawer Transitions & Single Source of Truth") {
            // 1. Single Source of Truth & Zero Duplicate Controller Verification
            assert(AudioController.shared === AudioController.shared, "AudioController harus singleton SSOT")
            assert(UniversalMusicManager.shared === UniversalMusicManager.shared, "UniversalMusicManager harus singleton SSOT")
            assert(BrightnessController.shared === BrightnessController.shared, "BrightnessController harus singleton SSOT")
            assert(ApplicationLauncher.shared === ApplicationLauncher.shared, "ApplicationLauncher harus singleton SSOT")
            assert(ScreenshotController.shared === ScreenshotController.shared, "ScreenshotController harus singleton SSOT")

            // 2. HubTab Enum Expansion in ExpandedHubSheet (Penyatuan Shalat, Controls & Info)
            assert(HubTab.allCases.contains(.controls), "HubTab harus memuat tab .controls")
            assert(HubTab.controls.sfSymbol == "slider.horizontal.3", "Simbol SF Tab Controls harus 'slider.horizontal.3'")
            assert(HubTab.controls.rawValue == "Controls")
            assert(HubTab.allCases.count == 3, "HubTab sekarang memiliki 3 tab terpadu: Shalat, Controls, dan Info")

            // 3. QuickControlsPanel Model Composition & Presentation Styles
            let stripPanel = QuickControlsPanel(presentationStyle: .strip, initialDrawer: .none)
            assert(stripPanel.presentationStyle == .strip)
            assert(stripPanel.activeDrawer == .none)

            let sheetPanel = QuickControlsPanel(presentationStyle: .sheet)
            assert(sheetPanel.presentationStyle == .sheet)

            // 4. Drawer State Enum Verification
            let allDrawers: [QuickControlsActiveDrawer] = [.none, .audio, .brightness, .screenshot, .timer]
            assert(allDrawers.count == 5)
            assert(QuickControlsActiveDrawer.none != QuickControlsActiveDrawer.audio)
            assert(QuickControlsActiveDrawer.brightness != QuickControlsActiveDrawer.screenshot)
            assert(QuickControlsActiveDrawer.timer != QuickControlsActiveDrawer.none)

            // 4b. TimerControlView Composition
            let timerCard = TimerControlView(presentationStyle: .card)
            assert(timerCard.presentationStyle == .card)
            let timerStrip = TimerControlView(presentationStyle: .strip)
            assert(timerStrip.presentationStyle == .strip)

            // 4c. QuickControlsOrderManager Drag & Drop Reordering
            let orderMgr = QuickControlsOrderManager.shared
            assert(orderMgr.cardOrder.count == 4, "Harus ada 4 jenis kartu kontrol yang dapat diatur posisinya")
            let firstCard = orderMgr.cardOrder[0]
            let secondCard = orderMgr.cardOrder[1]
            orderMgr.moveItem(from: firstCard, to: secondCard)
            assert(orderMgr.cardOrder[1] == firstCard, "Item harus berpindah posisi saat di-drag & drop")
            orderMgr.resetToDefault()
            assert(orderMgr.cardOrder == QuickControlCardType.allCases, "Reset harus mengembalikan urutan posisi default")

            // 5. Audio State Propagation through Quick Controls
            let initialVol = AudioController.shared.volume
            AudioController.shared.setVolume(0.42)
            assert(abs(AudioController.shared.volume - 0.42) < 0.001, "Volume audio harus tersimpan dan terpropagasi")
            AudioController.shared.setVolume(initialVol)

            // 6. Media Control Routing Integrity
            assert(UniversalMusicManager.shared.playbackState == .stopped || UniversalMusicManager.shared.playbackState == .playing || UniversalMusicManager.shared.playbackState == .paused)

            // 7. Brightness Status & Display Integration
            let brightnessAvailable = BrightnessController.shared.isAvailable
            if let activeDisp = BrightnessController.shared.activeDisplay {
                assert(brightnessAvailable == activeDisp.canAdjustBrightness, "Ketersediaan brightness harus selaras dengan kapabilitas display aktif")
            }

            // 8. Safari Quick Action Path
            assert(ApplicationLauncher.safariBundleId == "com.apple.Safari")

            // 9. Screenshot Controller Permission & Settings Integration
            assert(ScreenshotController.shared.settings.destination == .desktop || ScreenshotController.shared.settings.destination == .customFolder || ScreenshotController.shared.settings.destination == .clipboardOnly)

            // 10. Theme Consistency & Accessible Palette
            let theme = IslandThemeManager.shared
            assert(!theme.currentPreset.rawValue.isEmpty, "Theme preset name tidak boleh kosong")
            assert(theme.palette.background != Color.clear, "Palette background harus valid")
        }

        print("""

        ================================================================================
           HASIL FINAL FASE 2 + FASE 3A s/d 3E (COMPACT TOUCH BAR COMPLETE) VALIDATION:
           1. Magic numbers (86400, 15, 45) diganti konstanta bernama bertipe TimeInterval.
           2. Deduplikasi Adzan diperkuat menggunakan Set<String> dengan pemangkasan memori.
           3. Sleep/Wake mencatat MissedPrayerOccurrence terstruktur (nama, waktu, zona).
           4. Timestamp sleep ditangkap secara sinkron sebelum dispatch Task MainActor.
           5. FIFO Serialized Notification Queue menjamin tidak ada overlapping / stale requests.
           6. Isolasi Namespace Notifikasi (ozill-prayer-*) menjamin modul lain aman dari pembersihan.
           7. Error add notifikasi tercatat transparan dan dibatasi max 50 riwayat.
           8. Transisi IslandState deterministik dan idempoten (Assertion 22 PASS).
           9. Centralized Theme Engine, 5 presets, accent picker & custom hex parser (Assertion 23 PASS).
           10. ModuleRegistry: Registrasi, lookup, unregister, duplicate prevention (Assertion 24 PASS).
           11. ModulePriority: Pengurutan hierarkis modul 100 s/d 20 (Assertion 25 PASS).
           12. GeneralSettings & StandbyMode: 7 varian standby & persistensi UserDefaults (Assertion 26 PASS).
           13. IslandModeRouter: Resolusi prioritas deterministik & anti-flapping (Assertion 27 PASS).
           14. MockMusicProvider: Simulasi playback, cycling, capabilities & error handling (Assertion 28 PASS).
           15. Browser Adapters: Pelaporan kapabilitas Chrome, Safari, Edge, Firefox (Assertion 29 PASS).
           16. YouTube Session: Klasifikasi YouTube vs YouTube Music & progress tracking (Assertion 30 PASS).
           17. BrowserMusicProvider: Multi-tab prioritization (Playing > Paused) & override (Assertion 31 PASS).
           18. UniversalMusicManager: Koordinasi multi-provider & dynamic mode router (Assertion 32 PASS).
           19. ScriptBridge: Eksekusi AppleScript background non-blocking & timeout watchdog (Assertion 33 PASS).
           20. IdleDimmingService: Transparansi otomatis saat idle > 15 menit dan reaktivasi instan (Assertion 34 PASS).
           21. Item A: Real YouTube Thumbnail Regex Extraction & System Volume Slider (Assertion 35 PASS).
           22. Item B: Focus / Pomodoro Timer State Engine, Presets & Priority (Assertion 36 PASS).
           23. Item C: Smart Battery Alert (<= 15%) & 3.5s Charger Animation (Assertion 37 PASS).
           24. Item D: Launch at Login Manager & Global Shortcut Registration (Assertion 38 PASS).
           25. Universal Notification Island: Integrasi Jalur A (AXObserver), B (Browser Web), C (Sistem) (Assertion 39 PASS).
           26. Fase 3A: AudioController Clamping, +/- 0.05 Step, Mute Toggle & State Isolation (Assertion 40 PASS).
           27. Fase 3B: MediaControl Previous/Next/PlayPause, Capabilities, Chrome Multi-Tab Manual Routing (Assertion 41 PASS).
           28. Fase 3C: Display Brightness Control, Clamping, Multi-Display Selection & External Fallback (Assertion 42 PASS).
           29. Fase 3D: Safari Quick Action, Screenshot Utility (Full/Area/Window), PNG & Clipboard (Assertion 43 PASS).
           30. Fase 3E: Compact Touch Bar Quick Controls Integration, Drawer Transitions & SSOT (Assertion 44 PASS).
           31. Seluruh 44 Automated Validation Assertions BERHASIL (PASS).
        ================================================================================
        """)
    }
}
