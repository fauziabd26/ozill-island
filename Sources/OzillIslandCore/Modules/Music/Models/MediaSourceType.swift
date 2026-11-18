import Foundation

/// Sumber aplikasi asal pemutaran media pada sistem macOS.
public enum MediaSourceType: String, CaseIterable, Identifiable, Codable, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    case browser = "Web Browser"
    case podcast = "Podcasts"
    case system = "System Audio"
    case other = "Other Player"
    
    public var id: String { rawValue }
    
    public var sfSymbol: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "dot.radiowaves.left.and.right"
        case .youtubeMusic: return "play.rectangle.fill"
        case .browser: return "globe"
        case .podcast: return "antenna.radiowaves.left.and.right"
        case .system: return "speaker.wave.2.fill"
        case .other: return "play.circle.fill"
        }
    }
}
