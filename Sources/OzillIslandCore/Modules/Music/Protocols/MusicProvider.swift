import Foundation

public enum MusicProviderError: Error, LocalizedError, Equatable {
    case unsupportedAction(String)
    case providerUnavailable(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedAction(let msg): return "Aksi kontrol media tidak didukung: \(msg)"
        case .providerUnavailable(let msg): return "Penyedia media sedang tidak aktif/tersedia: \(msg)"
        case .executionFailed(let msg): return "Gagal mengeksekusi kontrol media: \(msg)"
        }
    }
}

/// Kapabilitas kontrol yang didukung oleh sebuah MusicProvider.
public struct MusicProviderCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let playPause    = MusicProviderCapabilities(rawValue: 1 << 0)
    public static let skipNext     = MusicProviderCapabilities(rawValue: 1 << 1)
    public static let skipPrevious = MusicProviderCapabilities(rawValue: 1 << 2)
    public static let seek         = MusicProviderCapabilities(rawValue: 1 << 3)
    public static let readArtwork  = MusicProviderCapabilities(rawValue: 1 << 4)
    
    public static let standardControls: MusicProviderCapabilities = [.playPause, .skipNext, .skipPrevious]
    public static let fullControls: MusicProviderCapabilities = [.playPause, .skipNext, .skipPrevious, .seek, .readArtwork]
}

/// Kontrak universal untuk adapter sumber pemutar musik pihak ketiga (Apple Music, Spotify, dsb).
public protocol MusicProvider: AnyObject, Sendable {
    var identifier: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    var capabilities: MusicProviderCapabilities { get }
    
    func fetchSnapshot() async -> NowPlayingItem?
    func fetchPlaybackState() async -> PlaybackState
    func playPause() async throws
    func next() async throws
    func previous() async throws
}
