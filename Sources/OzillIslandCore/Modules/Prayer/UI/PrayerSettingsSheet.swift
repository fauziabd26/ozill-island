import SwiftUI

public struct PrayerSettingsSheet: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var settings = PrayerSettings.shared
    @State private var selectedTab: Int = 0
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
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
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Pengaturan Waktu Shalat")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder to balance back button
                Text("       ")
                    .font(.system(size: 12))
            }
            .padding(.bottom, 4)
            
            // Picker Mode: Lokasi vs Waktu Shalat
            Picker("", selection: $selectedTab) {
                Text("Jadwal & Notifikasi").tag(0)
                Text("Lokasi").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if selectedTab == 0 {
                // Tab 0: Jadwal, Reminder, Adzan, Koreksi
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(PrayerName.fardhuPrayers) { prayer in
                            let pref = settings.preferences[prayer] ?? PrayerPreference()
                            
                            VStack(spacing: 6) {
                                HStack {
                                    Image(systemName: prayer.sfSymbol)
                                        .foregroundColor(.orange)
                                    Text(prayer.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { pref.enabled },
                                        set: { settings.update(prayer, enabled: $0) }
                                    ))
                                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                                    .labelsHidden()
                                }
                                
                                if pref.enabled {
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    // Reminder row
                                    HStack {
                                        Text("Pengingat:")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        Stepper("\(pref.reminderMinutes) menit sblm", value: Binding(
                                            get: { pref.reminderMinutes },
                                            set: { settings.update(prayer, reminderMinutes: $0) }
                                        ), in: 0...60, step: 5)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                    }
                                    
                                    // Adzan sound toggle row
                                    HStack {
                                        Text("Putar Adzan:")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { pref.adhanEnabled },
                                            set: { settings.update(prayer, adhanEnabled: $0) }
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .green))
                                        .labelsHidden()
                                    }
                                    
                                    // Koreksi Ihtiyati row (-5 to +5)
                                    HStack {
                                        Text("Koreksi Ihtiyati:")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        let adj = pref.adjustmentMinutes
                                        let sign = adj > 0 ? "+\(adj)" : "\(adj)"
                                        Stepper("\(sign) menit", value: Binding(
                                            get: { pref.adjustmentMinutes },
                                            set: { settings.update(prayer, adjustmentMinutes: $0) }
                                        ), in: -5...5)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.cyan)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.06))
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
                            .background(vm.audioManager.isPlaying ? Color.red.opacity(0.8) : Color.blue.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 4)
                    }
                }
                .frame(maxHeight: 280)
            } else {
                // Tab 1: Lokasi & Fallback
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Metode Deteksi Lokasi")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Picker("", selection: $settings.locationMode) {
                            Text("Otomatis (CoreLocation / Wi-Fi)").tag(LocationMode.automaticGPS)
                            Text("Manual Pilih Kota").tag(LocationMode.manualPreset)
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                        .foregroundColor(.white)
                    }
                    
                    if settings.locationMode == .automaticGPS {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Status GPS:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Text(vm.locationManager.statusMessage)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.cyan)
                            
                            Button(action: {
                                vm.locationManager.requestSingleLocation()
                            }) {
                                HStack {
                                    Image(systemName: "location.circle.fill")
                                    Text("Perbarui Lokasi GPS Sekarang")
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 4)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pilih Kota:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
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
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.top, 6)
                .frame(maxHeight: 280)
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(
            ZStack {
                Color.black.opacity(0.96)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }
}
