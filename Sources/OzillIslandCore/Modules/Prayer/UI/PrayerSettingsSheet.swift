import SwiftUI

public struct PrayerSettingsSheet: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var settings = PrayerSettings.shared
    @ObservedObject private var theme = IslandThemeManager.shared
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
            ZStack {
                palette.background
                RoundedRectangle(cornerRadius: 20)
                    .stroke(palette.border, lineWidth: 1)
            }
        )
        .cornerRadius(20)
        .shadow(color: palette.shadowColor, radius: 16, x: 0, y: 8)
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
                
                // 4. Reset Button
                resetThemeButton(palette: palette)
            }
        }
        .frame(maxHeight: 280)
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
                ZStack {
                    palette.background
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(palette.border, lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
