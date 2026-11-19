import SwiftUI

/// Tampilan tombol aksi cepat aplikasi (Safari) pada Touch Bar Ozill Island.
public struct ApplicationQuickActionView: View {
    @ObservedObject private var launcher = ApplicationLauncher.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @State private var isLaunching: Bool = false
    @State private var errorMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        Button(action: {
            Task { @MainActor in
                isLaunching = true
                errorMessage = nil
                let result = await launcher.launchSafari()
                isLaunching = false
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accent)
                
                Text("Safari")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(palette.primaryText)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(palette.cardBackground.opacity(isLaunching ? 0.9 : 0.7))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(errorMessage ?? "Buka atau aktifkan browser Safari")
        .accessibilityLabel("Buka Safari")
        .accessibilityHint("Mengaktifkan jendela Safari atau meluncurkannya jika belum berjalan")
    }
}
