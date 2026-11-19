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
    case timer
    case screenshot
}

/// Panel kendali ringkas (Compact Touch Bar) Ozill Island yang menyatukan seluruh fitur kontrol:
/// Media & Audio Player, Focus Timer, Display Brightness, Safari Quick Action, dan Screenshot Utility.
public struct QuickControlsPanel: View {
    @ObservedObject private var audioController = AudioController.shared
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var brightnessController = BrightnessController.shared
    @ObservedObject private var timerService = TimerService.shared
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

                // 4. Timer Quick Button
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        activeDrawer = .timer
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(timerService.state == .running ? accent : palette.primaryText)

                        Text(timerService.state == .running ? timerService.formattedRemainingTime : "Timer")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(timerService.state == .running ? accent : palette.secondaryText)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(timerService.state == .running ? accent.opacity(0.18) : palette.cardBackground.opacity(0.8))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Buka Kontrol Focus Timer")
                .accessibilityLabel("Timer \(timerService.formattedRemainingTime). Klik untuk membuka kontrol.")

                // 5. Safari Quick Launcher (Compact 32x32 pt in strip)
                ApplicationQuickActionView(showsTitle: false)

                // 6. Screenshot Utility (Compact 32x32 pt in strip, opens screenshot drawer)
                ScreenshotControlView(showsTitle: false, onTriggerModes: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        activeDrawer = .screenshot
                    }
                })

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

            case .timer:
                // Expanded Timer Bar
                HStack(spacing: 8) {
                    TimerControlView(presentationStyle: .strip)

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
                    .help("Selesai Mengatur Timer")
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
        let item = musicManager.currentItem

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Section 1: Media Player & Audio System Card (Penyatuan Musik & Volume)
                VStack(alignment: .leading, spacing: 8) {
                    // Header Bar Media
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accent)

                        Text("Pemutar Media & Audio")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(palette.primaryText)

                        Spacer()

                        if let src = item?.source {
                            Text(src.rawValue)
                                .font(.system(size: 8.5, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Capsule(style: .continuous).fill(accent.opacity(0.18)))
                                .foregroundColor(accent)
                        }

                        if musicManager.isPinnedToMusic {
                            HStack(spacing: 2) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 7.5))
                                Text("PIN")
                                    .font(.system(size: 8, weight: .heavy))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule(style: .continuous).fill(Color.orange.opacity(0.2)))
                            .foregroundColor(.orange)
                        }
                    }

                    // Artwork & Track Details
                    HStack(spacing: 10) {
                        // Artwork Thumbnail
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [accent.opacity(0.8), accent.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            if let artUrl = item?.artworkURL {
                                AsyncImage(url: artUrl) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        Image(systemName: item?.source.sfSymbol ?? "music.note")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    case .empty:
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            } else {
                                Image(systemName: item?.source.sfSymbol ?? "music.note")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }

                        // Title & Artist
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item?.title ?? "Tidak Ada Trek Aktif")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(palette.primaryText)
                                .lineLimit(1)

                            Text(item?.artist ?? "Putar audio / video di browser atau pemutar media")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(palette.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()
                    }

                    // Progress Bar (Jika trek memiliki durasi terukur)
                    if let it = item, it.duration > 0 {
                        VStack(spacing: 2) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule(style: .continuous)
                                        .fill(palette.border.opacity(0.8))
                                        .frame(height: 3)

                                    Capsule(style: .continuous)
                                        .fill(accent)
                                        .frame(width: max(0, geo.size.width * CGFloat(it.progress)), height: 3)
                                }
                            }
                            .frame(height: 3)

                            HStack {
                                Text(it.formattedPosition)
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(palette.secondaryText)
                                Spacer()
                                Text(it.formattedDuration)
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(palette.secondaryText)
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    // Media Controls Row
                    HStack(spacing: 8) {
                        MediaControlView(showsTitle: false)
                        Spacer()
                    }

                    Divider()
                        .background(palette.border.opacity(0.4))

                    // System Volume Slider Row
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Volume Sistem")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(palette.secondaryText)
                            Spacer()
                            Text(audioController.isMuted ? "Bisu" : "\(Int(audioController.volume * 100))%")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(audioController.isMuted ? .red : palette.secondaryText)
                        }

                        AudioControlView()
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.cardBackground.opacity(0.6))
                )

                // Section 2: Focus & Pomodoro Timer Card (Penyatuan Timer)
                TimerControlView(presentationStyle: .card)

                // Section 3: Display Brightness Card
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

                // Section 4: Quick Launchers (Safari & Screenshot with full titles)
                HStack(spacing: 10) {
                    ApplicationQuickActionView(showsTitle: true)
                    ScreenshotControlView(showsTitle: true)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 2)
        }
    }
}
