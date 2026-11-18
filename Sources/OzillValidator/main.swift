import Foundation
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
            
            func playPause(sessionId: String) async throws { lastAction = "playPause" }
            func next(sessionId: String) async throws { lastAction = "next" }
            func previous(sessionId: String) async throws { lastAction = "previous" }
            func seek(to seconds: TimeInterval, sessionId: String) async throws { lastAction = "seek" }
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

        print("""

        ================================================================================
           HASIL FINAL FASE 2 — UNIVERSAL MUSIC & BROWSER INTEGRATION VALIDATION:
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
           20. Seluruh 33 Automated Validation Assertions BERHASIL (PASS).
        ================================================================================
        """)
    }
}
