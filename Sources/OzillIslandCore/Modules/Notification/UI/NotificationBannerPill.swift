import SwiftUI

/// Banner notifikasi interaktif yang muncul di dalam Island saat ada notifikasi masuk (Jalur A, B, atau C).
public struct NotificationBannerPill: View {
    let notification: IslandNotification
    @ObservedObject private var theme = IslandThemeManager.shared
    @State private var isHovered: Bool = false
    
    public init(notification: IslandNotification) {
        self.notification = notification
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = notification.accentColor
        
        HStack(spacing: 9) {
            // Left: App Icon with Glowing Accent
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Image(systemName: notification.iconSymbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
            }
            
            // Middle: App Name & Message Preview
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(notification.appName.uppercased())
                        .font(.system(size: 8.5, weight: .heavy))
                        .foregroundColor(accent)
                    
                    Text("•")
                        .font(.system(size: 7))
                        .foregroundColor(palette.secondaryText.opacity(0.5))
                    
                    Text(notification.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                }
                
                Text(notification.message)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Dismiss 'X' Button
            Button(action: {
                NotificationIslandService.shared.dismissActiveNotification()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(palette.secondaryText)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(palette.cardBackground))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Tutup Notifikasi")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(width: 360, height: 40)
        .background(
            Capsule(style: .continuous)
                .fill(palette.background)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    accent.opacity(0.85),
                    lineWidth: 1.2
                )
        )
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 3)
        .onHover { hovering in
            self.isHovered = hovering
            if hovering {
                IdleDimmingService.shared.recordActivity()
            }
        }
        .onTapGesture {
            PrayerIslandViewModel.shared.expand()
        }
    }
}
