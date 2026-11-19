import SwiftUI
import CoreGraphics

/// Gaya presentasi untuk panel Quick Controls.
public enum QuickControlsPresentationStyle: Sendable {
    case strip // Tampilan 1-bar horizontal bergaya Apple Touch Bar
    case sheet // Tampilan terintegrasi penuh di dalam tab lembar ekspansi Hub
}

/// Drawer / panel slider aktif pada mode strip Touch Bar.
public enum QuickControlsActiveDrawer: Equatable, Sendable {
    case none
    case audio
    case brightness
    case screenshot
}

/// Panel kendali ringkas (Compact Touch Bar) Ozill Island yang menyatukan seluruh fitur kontrol:
/// Audio, Media, Brightness, Safari Quick Action, dan Screenshot Utility.
public struct QuickControlsPanel: View {
    @ObservedObject private var audioController = AudioController.shared
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var brightnessController = BrightnessController.shared
    @ObservedObject private var launcher = ApplicationLauncher.shared
    @ObservedObject private var screenshotController = ScreenshotController.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var presentationStyle: QuickControlsPresentationStyle
    @State public var activeDrawer: QuickControlsActiveDrawer = .none
    
    public init(
        presentationStyle: QuickControlsPresentationStyle = .strip,
        initialDrawer: QuickControlsActiveDrawer = .none
    ) {
        self.presentationStyle = presentationStyle
        self._activeDrawer = State(initialValue: initialDrawer)
    }
    
    private var speakerIcon: String {
        if audioController.isMuted || audioController.volume == 0 {
            return "speaker.slash.fill"
        } else if audioController.volume < 0.33 {
            return "speaker.fill"
        } else if audioController.volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
    
    public var body: some View {
        switch presentationStyle {
        case .strip:
            stripView
        case .sheet:
            sheetView
        }
    }
    
    // MARK: - Strip Presentation (Touch Bar 1-Row Bar)
    
    @ViewBuilder
    private var stripView: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        HStack(spacing: 6) {
            switch activeDrawer {
            case .none:
                // 1. Audio Quick Button
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        activeDrawer = .audio
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: speakerIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(audioController.isMuted ? .red : palette.primaryText)
                        
                        Text(audioController.isMuted ? "Bisu" : "\(Int(audioController.volume * 100))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(audioController.isMuted ? .red : palette.secondaryText)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(audioController.isMuted ? Color.red.opacity(0.18) : palette.cardBackground.opacity(0.8))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Buka Slider Volume Audio")
                .accessibilityLabel("Volume Audio \(Int(audioController.volume * 100)) persen. Klik untuk membuka slider.")
                
                // 2. Media Controls (Previous, Play/Pause, Next)
                MediaControlView()
                
                // 3. Brightness Quick Button
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        activeDrawer = .brightness
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: brightnessController.isAvailable ? "sun.max.fill" : "sun.slash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(brightnessController.isAvailable ? palette.primaryText : palette.secondaryText.opacity(0.4))
                        
                        Text(brightnessController.isAvailable ? "\(Int(brightnessController.brightness * 100))%" : "N/A")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(palette.secondaryText)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(palette.cardBackground.opacity(0.8))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(brightnessController.isAvailable ? "Buka Slider Kecerahan Layar" : "Kecerahan tidak didukung untuk layar ini")
                .accessibilityLabel(brightnessController.isAvailable ? "Kecerahan \(Int(brightnessController.brightness * 100)) persen. Klik untuk membuka slider." : "Kecerahan tidak didukung")
                
                // 4. Safari Quick Launcher
                ApplicationQuickActionView()
                
                // 5. Screenshot Utility
                ScreenshotControlView()
                
            case .audio:
                // Expanded Audio Slider Bar
                HStack(spacing: 8) {
                    AudioControlView()
                    
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                            activeDrawer = .none
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(palette.cardBackground))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Selesai Mengatur Volume")
                    .accessibilityLabel("Selesai")
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                
            case .brightness:
                // Expanded Brightness Slider Bar
                HStack(spacing: 8) {
                    BrightnessControlView()
                    
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                            activeDrawer = .none
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(palette.cardBackground))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Selesai Mengatur Kecerahan")
                    .accessibilityLabel("Selesai")
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                
            case .screenshot:
                ScreenshotModeSelectionView(onDismiss: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        activeDrawer = .none
                    }
                })
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
            }
        }
        .frame(height: 32)
    }
    
    // MARK: - Sheet Presentation (Full Hub Tab Content)
    
    @ViewBuilder
    private var sheetView: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        VStack(spacing: 12) {
            // Section 1: Audio Control Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: speakerIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(audioController.isMuted ? .red : accent)
                    Text("Kontrol Volume Audio Sistem")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                    Text(audioController.isMuted ? "Bisu" : "\(Int(audioController.volume * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(audioController.isMuted ? .red : palette.secondaryText)
                }
                
                AudioControlView()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.cardBackground.opacity(0.6))
            )
            
            // Section 2: Display Brightness Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: brightnessController.isAvailable ? "sun.max.fill" : "sun.slash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(brightnessController.isAvailable ? accent : palette.secondaryText.opacity(0.4))
                    Text("Kecerahan Layar (\(brightnessController.activeDisplay?.name ?? "Layar"))")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                    Text(brightnessController.isAvailable ? "\(Int(brightnessController.brightness * 100))%" : "Tidak Didukung")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(palette.secondaryText)
                }
                
                BrightnessControlView()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.cardBackground.opacity(0.6))
            )
            
            // Section 3: Media Control Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "music.note")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accent)
                    Text("Kontrol Pemutar Media")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                    if let title = musicManager.currentItem?.title {
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(palette.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                HStack {
                    MediaControlView(showsTitle: true)
                    Spacer()
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.cardBackground.opacity(0.6))
            )
            
            // Section 4: Quick Launchers (Safari & Screenshot)
            HStack(spacing: 10) {
                ApplicationQuickActionView()
                ScreenshotControlView()
                Spacer()
            }
            .padding(.horizontal, 4)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
