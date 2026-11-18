import SwiftUI

public struct CollapsedPrayerPill: View {
    @ObservedObject var vm: PrayerIslandViewModel
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        HStack(spacing: 12) {
            // Left: SF Symbol + Prayer Name & Time
            HStack(spacing: 7) {
                if vm.audioManager.isPlaying {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: vm.scheduler.nextPrayerName.sfSymbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accent)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.audioManager.isPlaying ? "Adzan \(vm.audioManager.currentPrayerName)" : vm.scheduler.nextPrayerName.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                    
                    if let schedule = vm.scheduler.schedule {
                        Text(schedule.formattedTime(for: vm.scheduler.nextPrayerName, timeZone: vm.locationManager.currentTimeZone))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(palette.secondaryText)
                    }
                }
            }
            
            Spacer(minLength: 12)
            
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
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
                .background(palette.cardBackground)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(width: 250, height: 38)
        .background(
            ZStack {
                palette.background
                RoundedRectangle(cornerRadius: 19)
                    .stroke(
                        isHovered ? palette.hoverBorder : palette.border,
                        lineWidth: isHovered ? 1.4 : 1.0
                    )
            }
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
        .scaleEffect(isHovered && !reduceMotion ? 1.03 : 1.0)
        .shadow(
            color: isHovered ? accent.opacity(0.35) : palette.shadowColor,
            radius: isHovered ? 14 : 8,
            x: 0,
            y: isHovered ? 6 : 4
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
