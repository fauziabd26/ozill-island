import Foundation

/// Status reproduksi audio/media pemutar musik.
public enum PlaybackState: String, CaseIterable, Sendable, Codable {
    case playing
    case paused
    case stopped
    case loading
    case unknown
    
    public var isPlaying: Bool {
        self == .playing
    }
}
