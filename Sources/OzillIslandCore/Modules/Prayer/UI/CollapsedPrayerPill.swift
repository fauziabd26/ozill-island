import SwiftUI

public struct CollapsedPrayerPill: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var sys = SystemInfoService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
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
                    
                    if let schedule = vm.scheduler.schedule {
                        Text(schedule.formattedTime(for: vm.scheduler.nextPrayerName, timeZone: vm.locationManager.currentTimeZone))
                            .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                            .foregroundColor(palette.secondaryText)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Center Glance: Tanggal & Jam
            HStack(spacing: 4) {
                Text(sys.shortDateMasehi)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(palette.secondaryText)
                Text("•")
                    .font(.system(size: 7))
                    .foregroundColor(palette.secondaryText.opacity(0.4))
                Text(sys.currentTimeString)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(palette.primaryText)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                Capsule(style: .continuous)
                    .fill(palette.cardBackground.opacity(0.7))
            )
            
            Spacer(minLength: 4)
            
            // Right: Countdown or Playing Indicator
            if vm.audioManager.isPlaying {
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
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 8.5))
                        .foregroundColor(palette.secondaryText)
                    Text(vm.scheduler.timeRemainingString)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(accent)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 290, height: 38)
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
