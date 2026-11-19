import SwiftUI

public enum HubTab: String, CaseIterable, Identifiable {
    case prayer = "Shalat"
    case music = "Musik"
    case timer = "Timer"
    case system = "Info"
    
    public var id: String { rawValue }
    
    public var sfSymbol: String {
        switch self {
        case .prayer: return "moon.stars.fill"
        case .music: return "music.note"
        case .timer: return "timer"
        case .system: return "calendar.badge.clock"
        }
    }
}

/// Lembar tampilan utama Ozill Island yang menyatukan seluruh modul:
/// Jadwal Shalat, Universal Media Player, dan Informasi Kalender / Sistem / Baterai.
public struct ExpandedHubSheet: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var router = IslandModeRouter.shared
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    
    @State private var selectedTab: HubTab = .prayer
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        VStack(spacing: 10) {
            // Top Drag Handle (Bisa di-drag untuk menggeser Island ke mana saja)
            Capsule(style: .continuous)
                .fill(palette.secondaryText.opacity(0.35))
                .frame(width: 38, height: 4.5)
                .padding(.top, -6)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .global)
                        .onChanged { value in
                            IslandWindowController.shared.startDrag()
                            IslandWindowController.shared.updateDrag(translation: value.translation)
                        }
                        .onEnded { value in
                            IslandWindowController.shared.endDrag(translation: value.translation)
                        }
                )
            
            // Header Bar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(accent)
                        Text("Ozill Island Hub")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(palette.primaryText)
                    }
                    
                    HStack(spacing: 4) {
                        Text(vm.locationManager.locationName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(palette.secondaryText)
                        
                        Button(action: {
                            vm.locationManager.requestSingleLocation()
                        }) {
                            Image(systemName: vm.locationManager.isLocating ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                .font(.system(size: 9))
                                .foregroundColor(palette.secondaryText)
                                .rotationEffect(.degrees(vm.locationManager.isLocating ? 360 : 0))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Refresh Lokasi GPS")
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Pin Music Button
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            musicManager.togglePin()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: musicManager.isPinnedToMusic ? "pin.fill" : "pin")
                                .font(.system(size: 11, weight: .bold))
                            if musicManager.isPinnedToMusic {
                                Text("PIN")
                                    .font(.system(size: 8.5, weight: .heavy))
                            }
                        }
                        .foregroundColor(musicManager.isPinnedToMusic ? .white : palette.secondaryText)
                        .padding(.horizontal, musicManager.isPinnedToMusic ? 7 : 0)
                        .frame(width: musicManager.isPinnedToMusic ? nil : 30, height: 30)
                        .background(
                            musicManager.isPinnedToMusic ?
                            AnyView(Capsule(style: .continuous).fill(accent)) :
                            AnyView(Circle().fill(palette.cardBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(musicManager.isPinnedToMusic ? "Lepas Pin Musik (Kembali ke Otomatis)" : "Pin Musik ke Island (Kunci agar tidak hilang)")
                    
                    if IslandWindowController.shared.customOffset != .zero {
                        Button(action: {
                            IslandWindowController.shared.resetPositionToDefault()
                        }) {
                            Image(systemName: "scope")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(palette.secondaryText)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(palette.cardBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Reset Posisi ke Tengah Atas")
                    }
                    
                    Button(action: {
                        vm.openSettings()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(palette.primaryText)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(palette.cardBackground)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Pengaturan & Preferensi")
                    
                    Button(action: {
                        vm.collapse()
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(palette.primaryText)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(palette.cardBackground)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Tutup (Collapse) Island")
                }
            }
            
            // Segmented Module Tab Bar
            HStack(spacing: 4) {
                ForEach(HubTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            self.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.sfSymbol)
                                .font(.system(size: 10, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .white : palette.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5.5)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedTab == tab ?
                            AnyView(Capsule(style: .continuous).fill(accent)) :
                            AnyView(Capsule(style: .continuous).fill(palette.cardBackground.opacity(0.6)))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Tab Content
            Group {
                switch selectedTab {
                case .prayer:
                    PrayerTabContent(vm: vm)
                case .music:
                    ExpandedMusicSheet()
                case .timer:
                    TimerTabContent()
                case .system:
                    SystemInfoSheet()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 380, height: 410)
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
            if router.currentMode == .music || musicManager.playbackState.isPlaying {
                self.selectedTab = .music
            }
        }
        .onChange(of: router.currentMode) { newMode in
            if newMode == .music {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    self.selectedTab = .music
                }
            }
        }
    }
}

/// Konten tabel shalat 5 waktu dan hisab falak
struct PrayerTabContent: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var theme = IslandThemeManager.shared
    
    var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        VStack(spacing: 8) {
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
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.red.opacity(0.85))
                    )
                    .foregroundColor(.white)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.green.opacity(0.15))
                )
            }
            
            // Hero: Next Prayer Card
            HStack(spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: vm.scheduler.nextPrayerName.sfSymbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Menjelang \(vm.scheduler.nextPrayerName.rawValue)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(palette.secondaryText)
                        
                        if let schedule = vm.scheduler.schedule {
                            Text(schedule.formattedTime(for: vm.scheduler.nextPrayerName, timeZone: vm.locationManager.currentTimeZone))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(palette.primaryText)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(vm.scheduler.timeRemainingString)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.cardBackground)
                        )
                    
                    Text("Hitung Mundur")
                        .font(.system(size: 9))
                        .foregroundColor(palette.secondaryText)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.cardBackground.opacity(0.7))
            )
            
            // Timetable 5 Waktu
            if let schedule = vm.scheduler.schedule {
                let now = Date()
                let next = vm.scheduler.nextPrayerName
                VStack(spacing: 3) {
                    ForEach(schedule.items, id: \.prayer.rawValue) { item in
                        let isNext = item.prayer == next
                        let isPassed = item.time < now && !isNext
                        
                        HStack {
                            HStack(spacing: 7) {
                                Image(systemName: item.prayer.sfSymbol)
                                    .font(.system(size: 11))
                                    .foregroundColor(isNext ? accent : palette.secondaryText)
                                    .frame(width: 14)
                                
                                Text(item.prayer.rawValue)
                                    .font(.system(size: 12, weight: isNext ? .bold : .medium))
                                    .foregroundColor(isNext ? palette.primaryText : (isPassed ? palette.secondaryText.opacity(0.6) : palette.primaryText))
                            }
                            
                            Spacer()
                            
                            if isNext {
                                Text("SELANJUTNYA")
                                    .font(.system(size: 8, weight: .heavy))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule(style: .continuous).fill(accent.opacity(0.18)))
                                    .foregroundColor(accent)
                            }
                            
                            Text(schedule.formattedTime(for: item.prayer, timeZone: vm.locationManager.currentTimeZone))
                                .font(.system(size: 12, weight: isNext ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isNext ? accent : (isPassed ? palette.secondaryText.opacity(0.6) : palette.primaryText))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            isNext ?
                            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(palette.cardBackground) :
                            nil
                        )
                    }
                }
            }
        }
    }
}
