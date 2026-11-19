import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

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
/// Mendukung drag-and-drop untuk mengatur posisi/urutan kartu kontrol serta drag-bar posisi layar Island.
public struct QuickControlsPanel: View {
    @ObservedObject private var audioController = AudioController.shared
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var brightnessController = BrightnessController.shared
    @ObservedObject private var timerService = TimerService.shared
    @ObservedObject private var launcher = ApplicationLauncher.shared
    @ObservedObject private var screenshotController = ScreenshotController.shared
    @ObservedObject private var orderManager = QuickControlsOrderManager.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var presentationStyle: QuickControlsPresentationStyle
    @State public var activeDrawer: QuickControlsActiveDrawer = .none
    @State private var draggedCard: QuickControlCardType? = nil

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

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // 1. Pengatur Posisi Layar Island (Drag gesture langsung dari Controls)
                screenPositionDragBar(palette: palette, accent: accent)

                // 2. Drag & Drop Reordering Header
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Urutan Kontrol (Tahan & drag untuk atur posisi)")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor(palette.secondaryText)

                    Spacer()

                    if orderManager.isCustomized {
                        Button("Reset Urutan") {
                            orderManager.resetToDefault()
                        }
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(accent)
                        .buttonStyle(PlainButtonStyle())
                        .help("Kembalikan urutan default")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)

                // 3. Dynamic Reorderable Cards
                ForEach(orderManager.cardOrder) { cardType in
                    cardView(for: cardType, palette: palette, accent: accent)
                        .opacity(draggedCard == cardType ? 0.55 : 1.0)
                        .onDrag {
                            self.draggedCard = cardType
                            return NSItemProvider(object: cardType.rawValue as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: QuickControlCardDropDelegate(
                            targetCard: cardType,
                            orderManager: orderManager,
                            draggedCard: $draggedCard
                        ))
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Screen Position Drag Bar

    @ViewBuilder
    private func screenPositionDragBar(palette: IslandColorPalette, accent: Color) -> some View {
        let offset = IslandWindowController.shared.customOffset
        let isDefault = offset == .zero

        HStack(spacing: 8) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Posisi Layar Floating Island")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(palette.primaryText)
                Text(isDefault ? "Posisi: Default Tengah Atas" : "Posisi: X \(Int(offset.width)), Y \(Int(offset.height))")
                    .font(.system(size: 9))
                    .foregroundColor(palette.secondaryText)
            }

            Spacer()

            // Drag Button: Pengguna bisa klik & tahan untuk menggeser Island ke mana saja
            HStack(spacing: 4) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 9.5))
                Text("Drag Posisi")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(accent.opacity(0.18))
            .foregroundColor(accent)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .help("Klik & seret untuk memindahkan posisi Island di layar")
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        IslandWindowController.shared.startDrag()
                        IslandWindowController.shared.updateDrag(translation: value.translation)
                    }
                    .onEnded { value in
                        IslandWindowController.shared.endDrag(translation: value.translation)
                    }
            )

            if !isDefault {
                Button(action: {
                    IslandWindowController.shared.resetPositionToDefault()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(palette.secondaryText)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(palette.cardBackground))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reset Posisi ke Tengah Atas")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.cardBackground.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.border.opacity(0.4), lineWidth: 0.8)
        )
    }

    // MARK: - Dynamic Card View Renderer

    @ViewBuilder
    private func cardView(for cardType: QuickControlCardType, palette: IslandColorPalette, accent: Color) -> some View {
        switch cardType {
        case .mediaAudio:
            mediaAudioCard(palette: palette, accent: accent)
        case .timer:
            timerCard(palette: palette, accent: accent)
        case .brightness:
            brightnessCard(palette: palette, accent: accent)
        case .quickActions:
            quickActionsCard(palette: palette, accent: accent)
        }
    }

    // MARK: - Card 1: Media Player & Audio

    @ViewBuilder
    private func mediaAudioCard(palette: IslandColorPalette, accent: Color) -> some View {
        let item = musicManager.currentItem

        VStack(alignment: .leading, spacing: 8) {
            // Header Bar Media dengan Drag Handle
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

                // Drag Handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondaryText.opacity(0.5))
                    .help("Tahan & seret untuk mengatur posisi kartu ini")
            }

            // Artwork & Track Details
            HStack(spacing: 10) {
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
    }

    // MARK: - Card 2: Focus & Pomodoro Timer

    @ViewBuilder
    private func timerCard(palette: IslandColorPalette, accent: Color) -> some View {
        TimerControlView(presentationStyle: .card)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondaryText.opacity(0.5))
                    .padding(10)
                    .help("Tahan & seret untuk mengatur posisi kartu ini")
            }
    }

    // MARK: - Card 3: Display Brightness

    @ViewBuilder
    private func brightnessCard(palette: IslandColorPalette, accent: Color) -> some View {
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

                // Drag Handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondaryText.opacity(0.5))
                    .help("Tahan & seret untuk mengatur posisi kartu ini")
            }

            BrightnessControlView()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardBackground.opacity(0.6))
        )
    }

    // MARK: - Card 4: Quick Launchers (Safari & Screenshot)

    @ViewBuilder
    private func quickActionsCard(palette: IslandColorPalette, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accent)
                Text("Aksi Cepat & Utilitas")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(palette.primaryText)
                Spacer()

                // Drag Handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondaryText.opacity(0.5))
                    .help("Tahan & seret untuk mengatur posisi kartu ini")
            }

            HStack(spacing: 10) {
                ApplicationQuickActionView(showsTitle: true)
                ScreenshotControlView(showsTitle: true)
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardBackground.opacity(0.6))
        )
    }
}

/// DropDelegate untuk menangani perpindahan posisi (reordering) kartu saat di-drag & drop.
private struct QuickControlCardDropDelegate: DropDelegate {
    let targetCard: QuickControlCardType
    @ObservedObject var orderManager: QuickControlsOrderManager
    @Binding var draggedCard: QuickControlCardType?

    func dropEntered(info: DropInfo) {
        guard let source = draggedCard, source != targetCard else { return }
        orderManager.moveItem(from: source, to: targetCard)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCard = nil
        return true
    }
}
