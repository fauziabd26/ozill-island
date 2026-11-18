import SwiftUI

public struct PrayerSettingsSheet: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var settings = PrayerSettings.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var launchManager = LaunchAtLoginManager.shared
    @ObservedObject private var sys = SystemInfoService.shared
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var notifService = NotificationIslandService.shared
    @State private var selectedTab: Int = 0
    @State private var customHexInput: String = ""
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        VStack(spacing: 12) {
            // Header
            HStack {
                Button(action: {
                    vm.closeToExpanded()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Kembali")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(palette.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(palette.cardBackground)
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Pengaturan Ozill Island")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(palette.primaryText)
                
                Spacer()
                
                Text("       ")
                    .font(.system(size: 12))
            }
            .padding(.bottom, 2)
            
            // Picker Mode: 3 Tabs
            Picker("", selection: $selectedTab) {
                Text("Jadwal").tag(0)
                Text("Lokasi").tag(1)
                Text("Tampilan").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if selectedTab == 0 {
                // Tab 0: Jadwal & Ihtiyati
                jadwalTab(palette: palette, accent: accent)
            } else if selectedTab == 1 {
                // Tab 1: Lokasi
                lokasiTab(palette: palette, accent: accent)
            } else {
                // Tab 2: Tampilan & Tema
                tampilanTab(palette: palette, accent: accent)
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.border, lineWidth: 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: palette.shadowColor, radius: 20, x: 0, y: 10)
        .onAppear {
            customHexInput = theme.customHex
        }
    }
    
    // MARK: - Tab 0: Jadwal & Ihtiyati
    @ViewBuilder
    private func jadwalTab(palette: IslandColorPalette, accent: Color) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Kebijakan Ihtiyati Box
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kebijakan Ihtiyati (Buffer Waktu):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.secondaryText)
                    
                    Picker("", selection: $settings.ihtiyatiPolicy) {
                        ForEach(IhtiyatiPolicy.allCases) { policy in
                            Text(policy.rawValue).tag(policy)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Group {
                        switch settings.ihtiyatiPolicy {
                        case .pureAstronomical:
                            Text("Hisab astronomis murni tanpa ihtiyati (Offset 0 menit). Koreksi manual dinonaktifkan.")
                                .foregroundColor(.cyan)
                                
                        case .custom:
                            Text("Menggunakan koreksi manual pengguna (-5 s/d +5 menit) dari hasil hisab mentah.")
                                .foregroundColor(accent)
                                
                        case .experimentalSihatSnapshot:
                            let (_, isCalibrated, desc) = settings.effectiveAdjustment(
                                for: .fajr,
                                cityName: vm.locationManager.locationName,
                                date: Date(),
                                timeZone: vm.locationManager.currentTimeZone
                            )
                            if isCalibrated {
                                Text("✅ " + desc)
                                    .foregroundColor(.green)
                            } else {
                                Text("⚠️ " + desc)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .font(.system(size: 9.5))
                }
                .padding(10)
                .background(palette.cardBackground)
                .cornerRadius(8)
                
                // Per-Prayer Config
                ForEach(PrayerName.fardhuPrayers) { prayer in
                    let pref = settings.preferences[prayer] ?? PrayerPreference()
                    let (totalAdj, _, _) = settings.effectiveAdjustment(
                        for: prayer,
                        cityName: vm.locationManager.locationName,
                        date: Date(),
                        timeZone: vm.locationManager.currentTimeZone
                    )
                    let totalAdjSign = totalAdj > 0 ? "+\(totalAdj)" : "\(totalAdj)"
                    let isPure = settings.ihtiyatiPolicy == .pureAstronomical
                    
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: prayer.sfSymbol)
                                .foregroundColor(accent)
                            Text(prayer.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(palette.primaryText)
                            
                            Spacer()
                            
                            Text("Total koreksi: \(totalAdjSign)m")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(isPure ? palette.secondaryText : .cyan)
                            
                            Toggle("", isOn: Binding(
                                get: { pref.enabled },
                                set: { settings.update(prayer, enabled: $0) }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: accent))
                            .labelsHidden()
                        }
                        
                        if pref.enabled {
                            Divider().background(palette.border)
                            
                            // Reminder row
                            HStack {
                                Text("Pengingat:")
                                    .font(.system(size: 11))
                                    .foregroundColor(palette.secondaryText)
                                Spacer()
                                Stepper("\(pref.reminderMinutes) menit sblm", value: Binding(
                                    get: { pref.reminderMinutes },
                                    set: { settings.update(prayer, reminderMinutes: $0) }
                                ), in: 0...60, step: 5)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(palette.primaryText)
                            }
                            
                            // Adzan sound toggle row
                            HStack {
                                Text("Putar Adzan:")
                                    .font(.system(size: 11))
                                    .foregroundColor(palette.secondaryText)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { pref.adhanEnabled },
                                    set: { settings.update(prayer, adhanEnabled: $0) }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .labelsHidden()
                            }
                            
                            // Manual Adjustment row (-5 to +5)
                            HStack {
                                Text(isPure ? "Koreksi Manual (Terkunci):" : "Koreksi Manual Pengguna:")
                                    .font(.system(size: 11))
                                    .foregroundColor(isPure ? palette.secondaryText.opacity(0.6) : palette.secondaryText)
                                Spacer()
                                let manual = pref.manualAdjustmentMinutes
                                let manualSign = manual > 0 ? "+\(manual)" : "\(manual)"
                                
                                if isPure {
                                    Text("0m (Offset Terkunci)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(palette.secondaryText)
                                } else {
                                    Stepper("\(manualSign) menit", value: Binding(
                                        get: { pref.manualAdjustmentMinutes },
                                        set: { settings.update(prayer, manualAdjustmentMinutes: $0) }
                                    ), in: -5...5)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(accent)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(palette.cardBackground)
                    .cornerRadius(10)
                }
                
                // Audio preview button
                Button(action: {
                    if vm.audioManager.isPlaying {
                        vm.audioManager.stop()
                    } else {
                        vm.audioManager.play(for: .fajr)
                    }
                }) {
                    HStack {
                        Image(systemName: vm.audioManager.isPlaying ? "stop.fill" : "play.fill")
                        Text(vm.audioManager.isPlaying ? "Stop Audio Adzan" : "Test Audio Adzan / Chime")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(vm.audioManager.isPlaying ? Color.red.opacity(0.85) : accent.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxHeight: 280)
    }
    
    // MARK: - Tab 1: Lokasi
    @ViewBuilder
    private func lokasiTab(palette: IslandColorPalette, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Metode Deteksi Lokasi")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(palette.primaryText)
                
                Picker("", selection: $settings.locationMode) {
                    Text("Otomatis (Layanan Lokasi macOS)").tag(LocationMode.automaticGPS)
                    Text("Pilihan Manual (Offline)").tag(LocationMode.manualPreset)
                }
                .pickerStyle(RadioGroupPickerStyle())
                .foregroundColor(palette.primaryText)
            }
            
            if settings.locationMode == .automaticGPS {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Status Layanan Lokasi:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                    Text(vm.locationManager.statusMessage)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.cyan)
                    
                    Button(action: {
                        vm.locationManager.requestSingleLocation()
                    }) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Perbarui Posisi Sekarang")
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(palette.cardBackground)
                        .foregroundColor(palette.primaryText)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.cardBackground)
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pilih Kota:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                    
                    Picker("", selection: Binding(
                        get: { settings.selectedCity },
                        set: { city in
                            settings.selectedCity = city
                            vm.locationManager.setManualCity(city)
                        }
                    )) {
                        ForEach(CityPreset.defaults) { city in
                            Text("\(city.name) (\(city.province))").tag(city)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text("Mode manual 100% offline tanpa akses internet maupun Layanan Lokasi.")
                        .font(.system(size: 10))
                        .foregroundColor(palette.secondaryText)
                        .padding(.top, 2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.cardBackground)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.top, 6)
        .frame(maxHeight: 280)
    }
    
    // MARK: - Tab 2: Tampilan & Tema
    @ViewBuilder
    private func tampilanTab(palette: IslandColorPalette, accent: Color) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // 1. Tema Preset
                presetSection(palette: palette, accent: accent)
                
                // 2. Aksen Warna
                accentSection(palette: palette, accent: accent)
                
                // 3. Live Preview
                livePreviewSection(palette: palette, accent: accent)
                
                // 4. Sistem & Integrasi macOS (Launch at Login, Shortcut, Test Charger)
                systemFeaturesSection(palette: palette, accent: accent)
                
                // 5. Reset Button
                resetThemeButton(palette: palette)
            }
        }
        .frame(maxHeight: 280)
    }
    
    @ViewBuilder
    private func systemFeaturesSection(palette: IslandColorPalette, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sistem & Integrasi macOS:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(palette.secondaryText)
            
            VStack(spacing: 8) {
                // Launch at Login Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Buka Otomatis saat Login")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(palette.primaryText)
                        Text("Jalankan Ozill Island setiap kali Mac menyala")
                            .font(.system(size: 9.5))
                            .foregroundColor(palette.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { val in
                            launchManager.setEnabled(val)
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: accent))
                    .labelsHidden()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.cardBackground)
                )
                
                // Pin Music Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text("Pin Pemutar Musik ke Island")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(palette.primaryText)
                            if musicManager.isPinnedToMusic {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(accent)
                            }
                        }
                        Text("Kunci Island ke modul musik agar tidak hilang saat jeda lagu")
                            .font(.system(size: 9.5))
                            .foregroundColor(palette.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { musicManager.isPinnedToMusic },
                        set: { _ in
                            musicManager.togglePin()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: accent))
                    .labelsHidden()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.cardBackground)
                )
                
                // Global Shortcut Info
                HStack(spacing: 8) {
                    Image(systemName: "command.square.fill")
                        .font(.system(size: 16))
                        .foregroundColor(accent)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pintasan Global: ⌘ + ⇧ + I")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.primaryText)
                        Text("Buka atau tutup Ozill Island dari aplikasi mana saja")
                            .font(.system(size: 9))
                            .foregroundColor(palette.secondaryText)
                    }
                    Spacer()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.cardBackground)
                )

                
                // Charger Animation Test Button
                Button(action: {
                    vm.collapse()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        sys.triggerChargerBanner()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.green)
                        Text("Uji Coba Animasi Charger (3.5s)")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12))
                    .foregroundColor(.green)
                    .cornerRadius(7)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Universal Notification Controls (Jalur A, B, C)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Notifikasi Aplikasi (WA, IG, dsb)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(palette.primaryText)
                            Text(notifService.isAccessibilityAuthorized ? "Izin Aksesibilitas: Aktif ✅" : "Izin Aksesibilitas: Belum Aktif ⚠️")
                                .font(.system(size: 9.5))
                                .foregroundColor(notifService.isAccessibilityAuthorized ? .green : .orange)
                        }
                        Spacer()
                        if !notifService.isAccessibilityAuthorized {
                            Button("Beri Izin") {
                                notifService.requestAccessibilityPermission()
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(accent.opacity(0.18))
                            .foregroundColor(accent)
                            .cornerRadius(6)
                        }
                    }
                    
                    // Tombol Uji Notifikasi
                    HStack(spacing: 6) {
                        Button("🧪 Tes WA") {
                            vm.collapse()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                notifService.simulateNotification(type: "whatsapp")
                            }
                        }
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                        
                        Button("🧪 Tes IG") {
                            vm.collapse()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                notifService.simulateNotification(type: "instagram")
                            }
                        }
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.pink.opacity(0.15))
                        .foregroundColor(.pink)
                        .cornerRadius(6)
                        
                        Button("🧪 Tes Telegram") {
                            vm.collapse()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                notifService.simulateNotification(type: "telegram")
                            }
                        }
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.cardBackground)
                )
            }
        }
    }
    
    @ViewBuilder
    private func presetSection(palette: IslandColorPalette, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tema Latar Belakang:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(palette.secondaryText)
            
            HStack(spacing: 6) {
                ForEach(IslandThemePreset.allCases) { preset in
                    presetButton(preset: preset, palette: palette, accent: accent)
                }
            }
        }
    }
    
    @ViewBuilder
    private func presetButton(preset: IslandThemePreset, palette: IslandColorPalette, accent: Color) -> some View {
        let isSelected = theme.preset == preset
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                theme.preset = preset
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: preset.iconName)
                    .font(.system(size: 14))
                Text(preset.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? accent.opacity(0.18) : palette.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accent : palette.border, lineWidth: isSelected ? 1.5 : 0.8)
            )
            .foregroundColor(isSelected ? accent : palette.primaryText)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func accentSection(palette: IslandColorPalette, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warna Aksen:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(palette.secondaryText)
            
            HStack(spacing: 8) {
                ForEach(IslandAccentColor.allCases) { item in
                    accentSwatch(item: item, palette: palette)
                }
            }
            
            if theme.accentColor == .custom {
                customHexRow(palette: palette, accent: accent)
            }
        }
    }
    
    @ViewBuilder
    private func accentSwatch(item: IslandAccentColor, palette: IslandColorPalette) -> some View {
        let isSelected = theme.accentColor == item
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                theme.accentColor = item
            }
        }) {
            ZStack {
                Circle()
                    .fill(item.color(customHex: theme.customHex))
                    .frame(width: 26, height: 26)
                
                if isSelected {
                    Circle()
                        .stroke(palette.primaryText, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(PlainButtonStyle())
        .help(item.displayName)
    }
    
    @ViewBuilder
    private func customHexRow(palette: IslandColorPalette, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text("Hex Code:")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.secondaryText)
            
            TextField("#00D2FF", text: $customHexInput, onCommit: {
                theme.customHex = customHexInput
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(size: 11, design: .monospaced))
            .frame(width: 100)
            
            Button("Terapkan") {
                theme.customHex = customHexInput
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accent.opacity(0.2))
            .foregroundColor(accent)
            .cornerRadius(6)
            
            Spacer()
        }
        .padding(.top, 2)
    }
    
    @ViewBuilder
    private func livePreviewSection(palette: IslandColorPalette, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live Preview:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(palette.secondaryText)
            
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accent)
                    Text("Dzuhur")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                    Text("11:47")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(palette.secondaryText)
                }
                
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                        .foregroundColor(palette.secondaryText)
                    Text("2j 14m")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(accent)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(palette.cardBackground)
                .cornerRadius(6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: accent.opacity(0.25), radius: 6, x: 0, y: 3)
        }
    }
    
    @ViewBuilder
    private func resetThemeButton(palette: IslandColorPalette) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                theme.resetToDefault()
                customHexInput = theme.customHex
            }
        }) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset Tema ke Default")
            }
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(palette.cardBackground)
            .foregroundColor(palette.secondaryText)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(palette.border, lineWidth: 0.8)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
    }
}
