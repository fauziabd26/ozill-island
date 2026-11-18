import SwiftUI

public struct ExpandedMusicSheet: View {
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        let item = musicManager.currentItem
        let isPlaying = musicManager.playbackState.isPlaying
        let caps = musicManager.activeProvider?.capabilities ?? .standardControls
        
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: item?.source.sfSymbol ?? "music.note")
                        .font(.system(size: 11))
                        .foregroundColor(accent)
                    
                    Text(item?.album ?? item?.source.rawValue ?? "Universal Media Player")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Collapse button
                Button(action: {
                    PrayerIslandViewModel.shared.collapse()
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(palette.primaryText)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(palette.cardBackground)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Tutup Island")
            }
            
            // Media Card (Thumbnail / Artwork & Info)
            HStack(spacing: 14) {
                // Artwork Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.8), accent.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                    
                    if let artUrl = item?.artworkURL {
                        AsyncImage(url: artUrl) { img in
                            img.resizable()
                               .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: item?.source.sfSymbol ?? "music.note")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: item?.source.sfSymbol ?? "music.note")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Title & Artist
                VStack(alignment: .leading, spacing: 3) {
                    Text(item?.title ?? "Tidak Ada Trek Aktif")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(2)
                    
                    Text(item?.artist ?? "Buka YouTube, Spotify, atau Apple Music")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                    
                    if let src = item?.source {
                        Text(src.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(accent.opacity(0.18))
                            )
                            .foregroundColor(accent)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.cardBackground)
            )
            
            // Progress Bar
            if let it = item, it.duration > 0 {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(palette.border)
                                .frame(height: 4)
                            
                            Capsule(style: .continuous)
                                .fill(accent)
                                .frame(width: max(0, geo.size.width * CGFloat(it.progress)), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack {
                        Text(it.formattedPosition)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(palette.secondaryText)
                        Spacer()
                        Text(it.formattedDuration)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(palette.secondaryText)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Controls (Previous, Play/Pause, Next)
            HStack(spacing: 24) {
                // Previous button
                Button(action: {
                    Task {
                        await musicManager.previous()
                    }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(caps.contains(.skipPrevious) ? palette.primaryText : palette.secondaryText.opacity(0.3))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!caps.contains(.skipPrevious))
                
                // Play / Pause button
                Button(action: {
                    Task {
                        await musicManager.playPause()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(accent)
                            .frame(width: 44, height: 44)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Next button
                Button(action: {
                    Task {
                        await musicManager.next()
                    }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(caps.contains(.skipNext) ? palette.primaryText : palette.secondaryText.opacity(0.3))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!caps.contains(.skipNext))
            }
            .padding(.vertical, 4)
            
            // Detected Sessions Chips (jika ada lebih dari 1 tab/provider)
            let sessions = musicManager.browserProvider.getDetectedSessions()
            if sessions.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tab Media Terdeteksi:")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(palette.secondaryText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sessions, id: \.id) { session in
                                Button(action: {
                                    musicManager.browserProvider.selectSession(id: session.id)
                                    Task {
                                        await musicManager.pollActiveMedia()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: session.isYouTubeMusic ? "play.rectangle.fill" : "globe")
                                            .font(.system(size: 8.5))
                                        Text(session.nowPlaying.title)
                                            .font(.system(size: 9.5, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(session.nowPlaying.title == item?.title ? accent.opacity(0.22) : palette.cardBackground)
                                    )
                                    .foregroundColor(session.nowPlaying.title == item?.title ? accent : palette.primaryText)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
            
            // Footer Info
            HStack {
                Text("Universal Media Controller • Apple Music, Spotify, YouTube Browser")
                    .font(.system(size: 9))
                    .foregroundColor(palette.secondaryText.opacity(0.7))
                Spacer()
                if let prov = musicManager.activeProvider {
                    Text(prov.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(palette.secondaryText.opacity(0.7))
                }
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.border, lineWidth: 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: palette.shadowColor, radius: 20, x: 0, y: 10)
    }
}
