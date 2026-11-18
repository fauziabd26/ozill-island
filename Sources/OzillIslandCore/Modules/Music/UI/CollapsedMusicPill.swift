import SwiftUI

public struct CollapsedMusicPill: View {
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false
    
    public init() {}
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        let item = musicManager.currentItem
        let isPlaying = musicManager.playbackState.isPlaying
        
        HStack(spacing: 10) {
            // Left: Source Icon & Title
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(item?.source == .youtubeMusic || item?.source == .browser ? Color.red.opacity(0.85) : accent.opacity(0.85))
                        .frame(width: 20, height: 20)
                    Image(systemName: item?.source.sfSymbol ?? "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item?.title ?? "Tidak Ada Musik")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                        .frame(maxWidth: 215, alignment: .leading)
                    
                    Text(item?.artist ?? "Pilih lagu di browser / player")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                        .frame(maxWidth: 215, alignment: .leading)
                }
            }
            
            Spacer(minLength: 8)
            
            // Right: Animated Visualizer / Play-Pause Button
            HStack(spacing: 6) {
                // Mini Waveform
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accent)
                            .frame(width: 2.5, height: isPlaying ? CGFloat(8 + (i * 3)) : 4)
                            .animation(isPlaying ? Animation.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15) : .default, value: isPlaying)
                    }
                }
                
                // Play / Pause mini button
                Button(action: {
                    Task {
                        await musicManager.playPause()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(palette.primaryText)
                        .frame(width: 22, height: 22)
                        .background(palette.cardBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
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
