import SwiftUI

public struct CollapsedPrayerPill: View {
    @ObservedObject var vm: PrayerIslandViewModel
    
    public var body: some View {
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
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.audioManager.isPlaying ? "Adzan \(vm.audioManager.currentPrayerName)" : vm.scheduler.nextPrayerName.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let schedule = vm.scheduler.schedule {
                        Text(schedule.formattedTime(for: vm.scheduler.nextPrayerName, timeZone: vm.locationManager.currentTimeZone))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
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
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                    Text(vm.scheduler.timeRemainingString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.95))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(width: 250, height: 38)
        .background(
            ZStack {
                Color.black.opacity(0.92)
                RoundedRectangle(cornerRadius: 19)
                    .stroke(vm.isHovered ? Color.white.opacity(0.28) : Color.white.opacity(0.12), lineWidth: 1)
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}
