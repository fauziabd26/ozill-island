import SwiftUI
import AppKit

/// Banner notifikasi interaktif yang muncul di dalam Island saat ada notifikasi masuk (Jalur A, B, atau C).
/// Dirancang dengan Apple Dynamic Island fluid spring physics, interactive hover-pause, dan hairline progress bar.
public struct NotificationBannerPill: View {
    let notification: IslandNotification
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var notifService = NotificationIslandService.shared
    
    @State private var isHovered: Bool = false
    @State private var isCloseHovered: Bool = false
    @State private var iconScale: CGFloat = 0.65
    @State private var progress: CGFloat = 1.0
    
    public init(notification: IslandNotification) {
        self.notification = notification
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = notification.accentColor
        
        ZStack(alignment: .bottom) {
            HStack(spacing: 9) {
                // Left: App Icon with Glowing Halo & Spring Pop
                ZStack {
                    Circle()
                        .fill(accent.opacity(isHovered ? 0.28 : 0.18))
                        .frame(width: 26, height: 26)
                    
                    Circle()
                        .stroke(accent.opacity(0.35), lineWidth: 0.8)
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: notification.iconSymbol)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(accent)
                        .scaleEffect(iconScale)
                }
                .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 1)
                
                // Middle: App Name & Message Preview
                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 5) {
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
                
                // Right: Interactive Dismiss 'X' Button
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        NotificationIslandService.shared.dismissActiveNotification()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isCloseHovered ? palette.primaryText : palette.secondaryText)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(isCloseHovered ? accent.opacity(0.25) : palette.cardBackground)
                        )
                        .scaleEffect(isCloseHovered ? 1.12 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.isCloseHovered = hovering
                    }
                }
                .help("Tutup Notifikasi")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .frame(width: 360, height: 40)
            
            // Bottom Hairline Progress Indicator (Auto-Dismiss Gauge)
            GeometryReader { geo in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.9), accent.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress), height: 1.5)
                    .opacity(isHovered ? 0.35 : 0.85)
                    .animation(notifService.isHoverPaused ? nil : .linear(duration: notification.duration), value: progress)
            }
            .frame(height: 1.5)
            .padding(.horizontal, 22)
            .padding(.bottom, 1.5)
        }
        .frame(width: 360, height: 40)
        .background(
            Capsule(style: .continuous)
                .fill(palette.background)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    accent.opacity(isHovered ? 0.95 : 0.75),
                    lineWidth: isHovered ? 1.4 : 1.1
                )
        )
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .scaleEffect(isHovered ? 1.018 : 1.0)
        .shadow(color: accent.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 10 : 7, x: 0, y: 2)
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isHovered)
        .onHover { hovering in
            self.isHovered = hovering
            if hovering {
                IdleDimmingService.shared.recordActivity()
                NotificationIslandService.shared.pauseDismiss()
            } else {
                NotificationIslandService.shared.resumeDismiss()
            }
        }
        .onTapGesture {
            handleNotificationTap()
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.65)) {
                self.iconScale = 1.0
            }
            // Mulai countdown progress bar
            self.progress = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.linear(duration: notification.duration)) {
                    self.progress = 0.0
                }
            }
        }
    }
    
    private func handleNotificationTap() {
        IdleDimmingService.shared.recordActivity()
        
        // Coba aktifkan aplikasi yang bersangkutan jika terpasang
        let appName = notification.appName.lowercased()
        if appName.contains("whatsapp") {
            if let wa = NSRunningApplication.runningApplications(withBundleIdentifier: "net.whatsapp.WhatsApp").first {
                wa.activate(options: .activateIgnoringOtherApps)
            } else if let chrome = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").first {
                chrome.activate(options: .activateIgnoringOtherApps)
            }
        } else if appName.contains("telegram") {
            if let tg = NSRunningApplication.runningApplications(withBundleIdentifier: "ru.keepcoder.Telegram").first {
                tg.activate(options: .activateIgnoringOtherApps)
            }
        }
        
        // Buka expanded sheet island
        PrayerIslandViewModel.shared.expand()
    }
}
