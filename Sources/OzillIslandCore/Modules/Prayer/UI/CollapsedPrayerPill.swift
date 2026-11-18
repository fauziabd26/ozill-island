import SwiftUI

public struct CollapsedPrayerPill: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var sys = SystemInfoService.shared
    @ObservedObject private var timerService = TimerService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        Group {
            if sys.showChargerConnectedBanner {
                // Smart Battery Charger Connected Pop-up (3.5 detik)
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 22, height: 22)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    Text("Pengisian Daya Tersambung")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(sys.batteryLevel)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.green.opacity(0.18))
                        )
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            } else {
                HStack(spacing: 8) {
                    // Left: SF Symbol + Prayer Name & Time
                    HStack(spacing: 6) {
                        if vm.audioManager.isPlaying {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: vm.scheduler.nextPrayerName.sfSymbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(accent)
                        }
                        
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text(vm.audioManager.isPlaying ? "Adzan \(vm.audioManager.currentPrayerName)" : vm.scheduler.nextPrayerName.rawValue)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundColor(palette.primaryText)
                                .lineLimit(1)
                            
                            if let schedule = vm.scheduler.schedule {
                                Text(schedule.formattedTime(for: vm.scheduler.nextPrayerName, timeZone: vm.locationManager.currentTimeZone))
                                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                                    .foregroundColor(palette.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    
                    Spacer(minLength: 6)
                    
                    // Center Glance: Timer aktif ATAU Tanggal & Jam
                    if timerService.state == .running || timerService.state == .paused {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 9.5))
                                .foregroundColor(accent)
                            Text(timerService.formattedRemainingTime)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(palette.primaryText)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.cardBackground.opacity(0.8))
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    } else {
                        HStack(spacing: 5) {
                            Text(sys.shortDateMasehi)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(palette.secondaryText)
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(palette.secondaryText.opacity(0.4))
                            Text(sys.currentTimeString)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(palette.primaryText)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.cardBackground.opacity(0.8))
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    Spacer(minLength: 6)
                    
                    // Right: Low Battery Warning / Adzan Stop / Countdown
                    if sys.isLowBatteryAlert {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9.5))
                                .foregroundColor(.red)
                            Text("\(sys.batteryLevel)%")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.red.opacity(0.16))
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    } else if vm.audioManager.isPlaying {
                        Button(action: {
                            vm.audioManager.stop()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 9))
                                Text("Stop")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.red.opacity(0.85))
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .fixedSize(horizontal: true, vertical: false)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 9))
                                .foregroundColor(palette.secondaryText)
                            Text(vm.scheduler.timeRemainingString)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.cardBackground)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(width: 360, height: 40)
        .background(
            Capsule(style: .continuous)
                .fill(palette.background)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    isHovered ? accent.opacity(0.85) : palette.border,
                    lineWidth: isHovered ? 1.4 : 1.0
                )
        )
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
        .shadow(
            color: isHovered ? accent.opacity(0.3) : Color.clear,
            radius: isHovered ? 4 : 0,
            x: 0,
            y: isHovered ? 1 : 0
        )
        .onHover { hovering in
            if hovering {
                IdleDimmingService.shared.recordActivity()
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            vm.expand()
        }
        .help("Klik untuk membuka Ozill Island")
    }
}
