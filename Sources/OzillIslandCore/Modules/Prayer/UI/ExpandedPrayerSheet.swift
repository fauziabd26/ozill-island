import SwiftUI

public struct ExpandedPrayerSheet: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var theme = IslandThemeManager.shared
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        VStack(spacing: 12) {
            // Header: Location & Action buttons
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(accent)
                    Text(vm.locationManager.locationName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    
                    Button(action: {
                        vm.locationManager.requestSingleLocation()
                    }) {
                        Image(systemName: vm.locationManager.isLocating ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(palette.secondaryText)
                            .rotationEffect(.degrees(vm.locationManager.isLocating ? 360 : 0))
                            .animation(vm.locationManager.isLocating ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.locationManager.isLocating)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh Lokasi GPS")
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        vm.openSettings()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(palette.primaryText)
                            .frame(width: 32, height: 32)
                            .background(palette.cardBackground)
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Pengaturan & Koreksi Waktu")
                    
                    Button(action: {
                        vm.collapse()
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(palette.primaryText)
                            .frame(width: 32, height: 32)
                            .background(palette.cardBackground)
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Tutup Island")
                }
            }
            
            // Missed prayer notice if Mac woke up after prayer onset
            if let missed = vm.scheduler.missedPrayerAlert {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 11))
                    Text(missed)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                    Button(action: {
                        vm.scheduler.clearMissedPrayerAlert()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.18))
                .cornerRadius(8)
            }
            
            // Audio alert bar if playing
            if vm.audioManager.isPlaying {
                HStack {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.green)
                    Text("Adzan \(vm.audioManager.currentPrayerName) sedang berkumandang")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                    Button("Hentikan") {
                        vm.audioManager.stop()
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
            }
            
            // Hero: Next Prayer Card
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)
                        Image(systemName: vm.scheduler.nextPrayerName.sfSymbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MENUJU WAKTU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(palette.secondaryText)
                        Text(vm.scheduler.nextPrayerName.rawValue)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(palette.primaryText)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let schedule = vm.scheduler.schedule {
                        Text(schedule.formattedTime(for: vm.scheduler.nextPrayerName, timeZone: vm.locationManager.currentTimeZone))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.primaryText)
                    }
                    Text(vm.scheduler.timeRemainingString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.cardBackground)
            .cornerRadius(12)
            
            // Full Prayer List (6 times including Syuruq)
            if let schedule = vm.scheduler.schedule {
                let now = Date()
                let next = vm.scheduler.nextPrayerName
                
                VStack(spacing: 4) {
                    ForEach(schedule.items, id: \.prayer.rawValue) { item in
                        let isNext = item.prayer == next
                        let isPassed = item.time < now && !isNext
                        
                        HStack {
                            Image(systemName: item.prayer.sfSymbol)
                                .font(.system(size: 11))
                                .foregroundColor(isNext ? accent : (isPassed ? palette.secondaryText.opacity(0.5) : palette.secondaryText))
                                .frame(width: 16)
                            
                            Text(item.prayer.rawValue)
                                .font(.system(size: 12, weight: isNext ? .bold : .regular))
                                .foregroundColor(isNext ? palette.primaryText : (isPassed ? palette.secondaryText.opacity(0.6) : palette.primaryText))
                            
                            Spacer()
                            
                            if isNext {
                                Text("Berikutnya")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.18))
                                    .foregroundColor(accent)
                                    .cornerRadius(4)
                            }
                            
                            Text(schedule.formattedTime(for: item.prayer, timeZone: vm.locationManager.currentTimeZone))
                                .font(.system(size: 12, weight: isNext ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isNext ? accent : (isPassed ? palette.secondaryText.opacity(0.6) : palette.primaryText))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isNext ? palette.cardBackground : Color.clear)
                        .cornerRadius(6)
                    }
                }
            }
            
            // Footer note
            HStack {
                Text("Hisab Falak (Subuh 20°, Isya 18°, Syafi'i) • Perhitungan Offline")
                    .font(.system(size: 9))
                    .foregroundColor(palette.secondaryText.opacity(0.7))
                Spacer()
                Text(vm.locationManager.currentTimeZone.identifier)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(palette.secondaryText.opacity(0.7))
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
    }
}
