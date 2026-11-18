# Ozill Island — Prayer Time Module for macOS (Intel 2019)

Aplikasi Dynamic Island native macOS yang melayang di layar bagian tengah atas (tepat di bawah Menu Bar), menghitung jadwal shalat secara offline berdasarkan standar Kemenag RI (Madhab Syafi'i), memberikan pengingat custom per waktu shalat, dan audio adzan.

## 🚀 Fitur Utama

- **Native macOS Dynamic Island UI**:
  - **Collapsed State**: Pill hitam elegan menampilkan nama shalat berikutnya, waktu masuk, dan countdown mundur presisi.
  - **Expanded State**: Klik pill untuk membuka dashboard jadwal lengkap harian (Subuh, Syuruq, Dzuhur, Ashar, Maghrib, Isya) beserta status waktu saat ini.
  - **Settings View**: Konfigurasi per-shalat (Aktif/Nonaktif, Pengingat 0-60 menit, Adzan audio ON/OFF, Koreksi manual Ihtiyati -5 s/d +5 menit).
- **Akurasi Standar Kemenag RI**:
  - Menggunakan library astronomi `Adhan Swift` v1.5.0.
  - Fajr Angle: 20°, Isha Angle: 18°, Madhab: Syafi'i.
  - Configurable Ihtiyati default +2 menit per waktu shalat fardhu (bisa disesuaikan manual -5 s/d +5 menit).
  - Tervalidasi presisi dengan jadwal resmi SIHAT Kemenag RI.
- **Location Management (Hierarki Fallback 100% Offline)**:
  1. CoreLocation (GPS / Wi-Fi positioning single-shot)
  2. Lokasi tersimpan lokal terakhir
  3. Pilihan manual 15 kota besar Indonesia (Default: DKI Jakarta)
- **Audio & Notifikasi**:
  - Playback audio via `AVAudioPlayer` (mendukung `Adhan.mp3` custom dan built-in `AdhanSample.wav`).
  - macOS native `UNUserNotificationCenter` untuk pengingat persiapan shalat dan notifikasi saat masuk waktu shalat.
  - Quick-action "Stop Adzan" langsung dari Dynamic Island.
- **MacBook Pro 16" Intel 2019 Ready**:
  - Target arsitektur: `x86_64`.
  - Floating `NSPanel` di level `.floating`, tidak mengganggu dock/menubar (`LSUIElement = true`).

---

## 🛠️ Cara Build & Menjalankan

### 1. Build & Packaging Otomatis menjadi `.app`
Cukup jalankan script:
```bash
./scripts/build_app.sh
```
Aplikasi hasil build akan langsung tersedia di:
`build/OzillIsland.app`

### 2. Jalankan Aplikasi
```bash
open build/OzillIsland.app
```

### 3. Validasi Perhitungan Jadwal Shalat (Engine Validator)
Untuk memverifikasi akurasi perhitungan shalat terhadap SIHAT Kemenag:
```bash
swift run OzillValidator
```

---

## 📂 Struktur Project

```
Dynamic Island by Fauzi/
├── Package.swift                  # Konfigurasi SPM & dependensi Adhan Swift
├── Sources/
│   ├── OzillIslandApp/            # Entry point aplikasi (@main)
│   ├── OzillIslandCore/
│   │   ├── AppDelegate.swift      # Menu bar status item & app lifecycle
│   │   ├── Core/Window/           # NSPanel floating window & auto-resizing
│   │   ├── Modules/Prayer/
│   │   │   ├── Models/            # PrayerName, PrayerSchedule, CityPreset
│   │   │   ├── Services/          # LocationManager, Calculator, Scheduler, Notification, Audio
│   │   │   └── UI/                # SwiftUI Dynamic Island (Collapsed, Expanded, Settings)
│   │   └── Resources/             # AdhanSample.wav (audio chime default)
│   └── OzillValidator/            # CLI test & validasi SIHAT Kemenag
├── Support/
│   └── Info.plist                 # Bundle metadata & izin CoreLocation
└── scripts/
    └── build_app.sh               # Otomasi build release & packaging .app bundle
```
