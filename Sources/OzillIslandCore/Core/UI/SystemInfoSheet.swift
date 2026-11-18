import SwiftUI

/// Lembar tampilan informasi sistem, kalender masehi, kalender hijriah, jam digital, dan status daya baterai Mac.
public struct SystemInfoSheet: View {
    @ObservedObject private var sys = SystemInfoService.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var prayerVM = PrayerIslandViewModel.shared
    
    public init() {}
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        VStack(spacing: 12) {
            // Jam Digital Realtime & Detik
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(sys.currentTimeString)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(palette.primaryText)
                
                Text(sys.currentSecondsString)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent)
                
                Spacer()
                
                // Battery Badge
                HStack(spacing: 5) {
                    Image(systemName: sys.batteryIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(sys.isBatteryCharging || sys.batteryLevel > 20 ? .green : .red)
                    
                    Text("\(sys.batteryLevel)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(palette.primaryText)
                    
                    if sys.isACPluggedIn {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground)
                )
            }
            
            // Tanggal Masehi & Hijriah
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(accent)
                    Text(sys.currentDateMasehi)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 11))
                        .foregroundColor(palette.secondaryText)
                    Text(sys.currentDateHijri)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(palette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.cardBackground)
            )
            
            // Ringkasan Waktu Shalat Terdekat
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: prayerVM.scheduler.nextPrayerName.sfSymbol)
                        .foregroundColor(accent)
                    Text(prayerVM.scheduler.nextPrayerName.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                }
                
                Spacer()
                
                if let schedule = prayerVM.scheduler.schedule {
                    Text(schedule.formattedTime(for: prayerVM.scheduler.nextPrayerName, timeZone: prayerVM.locationManager.currentTimeZone))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(palette.primaryText)
                }
                
                Text(prayerVM.scheduler.timeRemainingString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.15))
                    )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.cardBackground)
            )
        }
    }
}
