import Foundation

/// Model data metadata trek lagu / media yang sedang diputar.
public struct NowPlayingItem: Equatable, Hashable, Sendable, Codable {
    public let title: String
    public let artist: String
    public let album: String?
    public let artworkURL: URL?
    public let duration: TimeInterval
    public let playbackPosition: TimeInterval
    public let source: MediaSourceType
    
    public init(
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval = 0,
        playbackPosition: TimeInterval = 0,
        source: MediaSourceType = .other
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = max(0, duration)
        self.playbackPosition = min(max(0, playbackPosition), max(0, duration))
        self.source = source
    }
    
    /// Persentase progres pemutaran [0.0 ... 1.0]
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(0, playbackPosition / duration), 1.0)
    }
    
    /// Format string posisi waktu (mm:ss)
    public var formattedPosition: String {
        Self.formatTime(playbackPosition)
    }
    
    /// Format string durasi total (mm:ss)
    public var formattedDuration: String {
        Self.formatTime(duration)
    }
    
    private static func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
