import SwiftUI
import CoreGraphics

/// Panel pemilihan mode tangkapan layar (Full Screen, Area, Window) pada Touch Bar.
public struct ScreenshotModeSelectionView: View {
    @ObservedObject private var controller = ScreenshotController.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var onDismiss: () -> Void
    
    public init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        HStack(spacing: 8) {
            // Full Screen Mode Button (32x32 pt hit target)
            Button(action: {
                Task { @MainActor in
                    _ = await controller.executeCapture(mode: .fullScreen)
                    onDismiss()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "display")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accent)
                    Text("Layar")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground.opacity(0.8))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Tangkap seluruh layar tampilan utama")
            .accessibilityLabel("Tangkap layar penuh")
            
            // Area Selection Mode Button (32x32 pt hit target)
            Button(action: {
                Task { @MainActor in
                    // Mengambil area default layar atau memicu seleksi
                    let mainFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
                    let centerArea = CGRect(
                        x: mainFrame.width * 0.2,
                        y: mainFrame.height * 0.2,
                        width: mainFrame.width * 0.6,
                        height: mainFrame.height * 0.6
                    )
                    _ = await controller.executeCapture(mode: .selectedArea, rect: centerArea)
                    onDismiss()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accent)
                    Text("Area")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground.opacity(0.8))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Pilih dan tangkap area tertentu")
            .accessibilityLabel("Tangkap area tertentu")
            
            // Window Mode Button (32x32 pt hit target)
            Button(action: {
                Task { @MainActor in
                    await controller.refreshCaptureableWindows()
                    if let firstWindow = controller.availableWindows.first {
                        _ = await controller.executeCapture(mode: .window, windowId: firstWindow.id)
                    } else {
                        _ = await controller.executeCapture(mode: .fullScreen)
                    }
                    onDismiss()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accent)
                    Text("Jendela")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground.opacity(0.8))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Tangkap jendela aplikasi aktif")
            .accessibilityLabel("Tangkap jendela aplikasi")
            
            // Dismiss / Back Button (32x32 pt hit target)
            Button(action: {
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(palette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.cardBackground.opacity(0.6)))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Tutup pilihan mode screenshot")
            .accessibilityLabel("Tutup pilihan mode")
        }
        .frame(height: 32)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: controller.isCapturing)
    }
}
