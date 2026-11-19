import SwiftUI

/// Tampilan tombol Screenshot utama pada Touch Bar dengan transisi ke pemilih mode.
public struct ScreenshotControlView: View {
    @ObservedObject private var controller = ScreenshotController.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingModes: Bool = false
    
    public init() {}
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        Group {
            if isShowingModes {
                ScreenshotModeSelectionView(onDismiss: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                        isShowingModes = false
                    }
                })
            } else {
                Button(action: {
                    if !controller.checkPermission() {
                        controller.openPermissionSettings()
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                            isShowingModes = true
                        }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accent)
                        
                        Text("Screenshot")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(palette.primaryText)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(palette.cardBackground.opacity(0.7))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(accent.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(controller.checkPermission() ? "Ambil tangkapan layar (Full Screen, Area, Window)" : "Izin Screen Recording belum aktif. Klik untuk buka Pengaturan.")
                .accessibilityLabel("Tangkapan layar")
                .accessibilityHint("Buka pilihan mode tangkapan layar")
            }
        }
        .frame(height: 32)
    }
}
