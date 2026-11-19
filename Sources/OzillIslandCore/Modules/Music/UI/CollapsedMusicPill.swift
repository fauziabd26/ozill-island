import SwiftUI

public struct CollapsedMusicPill: View {
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var sys = SystemInfoService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false

    public init() {}

    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        let item = musicManager.currentItem
        let isPlaying = musicManager.playbackState.isPlaying
        let caps = musicManager.activeProvider?.capabilities ?? .standardControls

        Group {
            if sys.showChargerConnectedBanner {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 22, height: 22)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }

                    Text("Pengisian Daya Tersambung")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)

                    Spacer()

                    Text("\(sys.batteryLevel)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.green.opacity(0.18))
                        )
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            } else {
                HStack(spacing: 8) {
                    // Left: Source Icon & Title
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(item?.source == .youtubeMusic || item?.source == .browser ? Color.red.opacity(0.85) : accent.opacity(0.85))
                                .frame(width: 20, height: 20)
                            Image(systemName: item?.source.sfSymbol ?? "music.note")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(item?.title ?? "Tidak Ada Musik")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(palette.primaryText)
                                    .lineLimit(1)

                                if musicManager.isPinnedToMusic {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(accent)
                                }
                            }
                            .frame(maxWidth: 165, alignment: .leading)

                            Text(item?.artist ?? "Pilih lagu di browser / player")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(palette.secondaryText)
                                .lineLimit(1)
                                .frame(maxWidth: 165, alignment: .leading)
                        }
                    }

                    Spacer(minLength: 4)

                    // Controls: Previous, Play/Pause, Next & Equalizer Waveform
                    HStack(spacing: 4) {
                        // Previous Button
                        Button(action: {
                            Task {
                                await musicManager.previous()
                            }
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(caps.contains(.skipPrevious) ? palette.primaryText : palette.secondaryText.opacity(0.35))
                                .frame(width: 20, height: 20)
                                .background(palette.cardBackground.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!caps.contains(.skipPrevious))
                        .help("Lagu Sebelumnya")

                        // Play / Pause Button
                        Button(action: {
                            Task {
                                await musicManager.playPause()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(isPlaying ? accent : palette.primaryText)
                                .frame(width: 22, height: 22)
                                .background(isPlaying ? accent.opacity(0.18) : palette.cardBackground)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(isPlaying ? "Jeda" : "Putar")

                        // Next Button
                        Button(action: {
                            Task {
                                await musicManager.next()
                            }
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(caps.contains(.skipNext) ? palette.primaryText : palette.secondaryText.opacity(0.35))
                                .frame(width: 20, height: 20)
                                .background(palette.cardBackground.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!caps.contains(.skipNext))
                        .help("Lagu Berikutnya")

                        // Equalizer Waveform Visualizer (Driven by continuous timeline - never freezes)
                        MusicWaveformVisualizer(isPlaying: isPlaying, accent: accent)
                            .padding(.leading, 2)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 360, height: 40)
        .background(
            Capsule(style: .continuous)
                .fill(palette.background)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    isHovered ? accent.opacity(0.85) : palette.border,
                    lineWidth: isHovered ? 1.4 : 1.0
                )
        )
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
        .shadow(
            color: isHovered ? accent.opacity(0.3) : Color.clear,
            radius: isHovered ? 4 : 0,
            x: 0,
            y: isHovered ? 1 : 0
        )
        .onHover { hovering in
            if hovering {
                IdleDimmingService.shared.recordActivity()
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            PrayerIslandViewModel.shared.expand()
        }
        .help("Klik untuk membuka kontrol musik Ozill Island")
    }
}

/// Visualizer gelombang musik yang dianimasikan secara deterministik menggunakan TimelineView.
/// Mengatasi masalah freeze/stuck saat pergantian trek lagu tanpa perlu pause manual.
private struct MusicWaveformVisualizer: View {
    let isPlaying: Bool
    let accent: Color

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let time = isPlaying ? timeline.date.timeIntervalSinceReferenceDate : 0
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    let offset = Double(i) * 1.15
                    let wave = isPlaying ? (sin((time * 8.5) + offset) + 1.0) / 2.0 : 0.0
                    let barHeight = isPlaying ? CGFloat(4.0 + (wave * 9.0)) : 4.0

                    RoundedRectangle(cornerRadius: 1)
                        .fill(accent)
                        .frame(width: 2.5, height: barHeight)
                }
            }
        }
        .frame(width: 12, height: 14)
    }
}
