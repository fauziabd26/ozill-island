import SwiftUI

/// Tampilan kontrol pemutar media horizontal terinspirasi Touch Bar MacBook.
/// Menyediakan kontrol Previous, Play/Pause, dan Next yang terintegrasi langsung
/// dengan UniversalMusicManager, menghormati kapabilitas provider aktif, dan mendukung
/// seleksi manual tab browser secara deterministik.
public struct MediaControlView: View {
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    
    public var showsTitle: Bool
    
    public init(showsTitle: Bool = false) {
        self.showsTitle = showsTitle
    }
    
    private var hasActiveMedia: Bool {
        musicManager.activeProvider != nil && musicManager.currentItem != nil
    }
    
    private var capabilities: MusicProviderCapabilities {
        musicManager.activeProvider?.capabilities ?? []
    }
    
    private var canPrevious: Bool {
        hasActiveMedia && capabilities.contains(.skipPrevious)
    }
    
    private var canPlayPause: Bool {
        hasActiveMedia && capabilities.contains(.playPause)
    }
    
    private var canNext: Bool {
        hasActiveMedia && capabilities.contains(.skipNext)
    }
    
    private var isPlaying: Bool {
        musicManager.playbackState.isPlaying
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        HStack(spacing: 6) {
            // Previous Track Button (Hit Target 32x32 pt)
            Button(action: {
                Task {
                    await musicManager.previous()
                }
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(canPrevious ? palette.primaryText : palette.secondaryText.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardBackground.opacity(canPrevious ? 0.8 : 0.35))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canPrevious)
            .help(canPrevious ? "Lagu Sebelumnya (Previous)" : "Previous tidak didukung")
            .accessibilityLabel("Lagu sebelumnya")
            
            // Play / Pause Button (Hit Target 32x32 pt)
            Button(action: {
                Task {
                    await musicManager.playPause()
                }
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(canPlayPause ? (isPlaying ? accent : palette.primaryText) : palette.secondaryText.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(canPlayPause ? (isPlaying ? accent.opacity(0.18) : palette.cardBackground) : palette.cardBackground.opacity(0.35))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canPlayPause)
            .help(canPlayPause ? (isPlaying ? "Jeda (Pause)" : "Putar (Play)") : "Tidak ada media aktif")
            .accessibilityLabel(isPlaying ? "Jeda pemutaran" : "Mulai pemutaran")
            
            // Next Track Button (Hit Target 32x32 pt)
            Button(action: {
                Task {
                    await musicManager.next()
                }
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(canNext ? palette.primaryText : palette.secondaryText.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardBackground.opacity(canNext ? 0.8 : 0.35))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canNext)
            .help(canNext ? "Lagu Berikutnya (Next)" : "Next tidak didukung")
            .accessibilityLabel("Lagu berikutnya")
            
            if showsTitle {
                if let item = musicManager.currentItem {
                    HStack(spacing: 4) {
                        Image(systemName: item.source.sfSymbol)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(accent)
                        
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(palette.primaryText)
                            .lineLimit(1)
                            .frame(maxWidth: 100, alignment: .leading)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(palette.cardBackground.opacity(0.6))
                    )
                } else {
                    Text("Tidak Ada Media")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(palette.secondaryText.opacity(0.6))
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.background.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.border.opacity(0.6), lineWidth: 0.8)
        )
    }
}
