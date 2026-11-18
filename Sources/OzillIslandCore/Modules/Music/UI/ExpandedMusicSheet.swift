import SwiftUI

public struct ExpandedMusicSheet: View {
    @ObservedObject private var musicManager = UniversalMusicManager.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @ObservedObject private var volumeService = SystemVolumeService.shared
    
    public init() {}
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        let item = musicManager.currentItem
        let isPlaying = musicManager.playbackState.isPlaying
        let caps = musicManager.activeProvider?.capabilities ?? .standardControls
        
        VStack(spacing: 10) {
            // Media Card (Thumbnail / Artwork & Info)
            HStack(spacing: 12) {
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
                        .frame(width: 52, height: 52)
                    
                    if let artUrl = item?.artworkURL {
                        AsyncImage(url: artUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: item?.source.sfSymbol ?? "music.note")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.6)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: item?.source.sfSymbol ?? "music.note")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Title & Artist
                VStack(alignment: .leading, spacing: 2.5) {
                    Text(item?.title ?? "Tidak Ada Trek Aktif")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(2)
                    
                    Text(item?.artist ?? "Putar video di YouTube, Spotify, atau Apple Music")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let src = item?.source {
                            Text(src.rawValue)
                                .font(.system(size: 8.5, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(accent.opacity(0.18))
                                )
                                .foregroundColor(accent)
                        }
                        
                        if musicManager.isPinnedToMusic {
                            HStack(spacing: 2) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 7.5))
                                Text("PINNED")
                                    .font(.system(size: 8, weight: .heavy))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule(style: .continuous).fill(Color.orange.opacity(0.2)))
                            .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.cardBackground)
            )
            
            // Progress Bar
            if let it = item, it.duration > 0 {
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(palette.border)
                                .frame(height: 3.5)
                            
                            Capsule(style: .continuous)
                                .fill(accent)
                                .frame(width: max(0, geo.size.width * CGFloat(it.progress)), height: 3.5)
                        }
                    }
                    .frame(height: 3.5)
                    
                    HStack {
                        Text(it.formattedPosition)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(palette.secondaryText)
                        Spacer()
                        Text(it.formattedDuration)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(palette.secondaryText)
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // Controls (Previous, Play/Pause, Next)
            HStack(spacing: 24) {
                Button(action: {
                    Task { await musicManager.previous() }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 15))
                        .foregroundColor(caps.contains(.skipPrevious) ? palette.primaryText : palette.secondaryText.opacity(0.3))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!caps.contains(.skipPrevious))
                
                Button(action: {
                    Task { await musicManager.playPause() }
                }) {
                    ZStack {
                        Circle()
                            .fill(accent)
                            .frame(width: 40, height: 40)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    Task { await musicManager.next() }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15))
                        .foregroundColor(caps.contains(.skipNext) ? palette.primaryText : palette.secondaryText.opacity(0.3))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!caps.contains(.skipNext))
            }
            .padding(.vertical, 2)
            
            // Volume & Quick Mute Slider
            HStack(spacing: 8) {
                Button(action: {
                    volumeService.toggleMute()
                }) {
                    Image(systemName: volumeService.isMuted ? "speaker.slash.fill" : (volumeService.volume < 0.33 ? "speaker.fill" : (volumeService.volume < 0.66 ? "speaker.wave.1.fill" : "speaker.wave.2.fill")))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(volumeService.isMuted ? .red : palette.secondaryText)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(palette.cardBackground))
                }
                .buttonStyle(PlainButtonStyle())
                .help(volumeService.isMuted ? "Bunyikan Audio" : "Bisu (Mute)")
                
                GeometryReader { vGeo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(palette.border)
                            .frame(height: 5)
                        
                        Capsule(style: .continuous)
                            .fill(volumeService.isMuted ? palette.secondaryText.opacity(0.4) : accent)
                            .frame(width: max(0, vGeo.size.width * CGFloat(volumeService.volume)), height: 5)
                    }
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let pct = Double(val.location.x / vGeo.size.width)
                                volumeService.setVolume(pct)
                            }
                    )
                }
                .frame(height: 24)
                
                Text("\(Int(volumeService.volume * 100))%")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(palette.secondaryText)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.cardBackground.opacity(0.5))
            )
            
            // Detected Sessions Chips
            let sessions = musicManager.browserProvider.getDetectedSessions()
            if sessions.count > 1 {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pilih Tab Media:")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(palette.secondaryText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(sessions, id: \.id) { session in
                                Button(action: {
                                    musicManager.browserProvider.selectSession(id: session.id)
                                    Task { await musicManager.pollActiveMedia() }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: session.isYouTubeMusic ? "play.rectangle.fill" : "globe")
                                            .font(.system(size: 8))
                                        Text(session.nowPlaying.title)
                                            .font(.system(size: 9, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
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
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
