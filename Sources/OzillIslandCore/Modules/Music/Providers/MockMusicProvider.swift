import Foundation

/// Provider simulasi pemutar media untuk pengujian TDD, automated validator, dan preview.
/// Didesain thread-safe dengan lock internal dan kompatibel penuh dengan Sendable di Swift 6.
public final class MockMusicProvider: MusicProvider, @unchecked Sendable {
    public let identifier: String
    public let displayName: String
    
    private let lock = NSLock()
    private var _isAvailable: Bool
    private var _capabilities: MusicProviderCapabilities
    private var playlist: [NowPlayingItem]
    private var currentIndex: Int = 0
    private var _playbackState: PlaybackState = .paused
    private var currentPosition: TimeInterval = 0
    
    public var isAvailable: Bool {
        lock.withLock { _isAvailable }
    }
    
    public var capabilities: MusicProviderCapabilities {
        lock.withLock { _capabilities }
    }
    
    public init(
        identifier: String = "org.ozill.provider.mock",
        displayName: String = "Mock Music Player",
        isAvailable: Bool = true,
        capabilities: MusicProviderCapabilities = .fullControls,
        initialTracks: [NowPlayingItem]? = nil
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self._isAvailable = isAvailable
        self._capabilities = capabilities
        
        let defaults: [NowPlayingItem] = [
            NowPlayingItem(
                title: "Starboy",
                artist: "The Weeknd ft. Daft Punk",
                album: "Starboy",
                duration: 230,
                playbackPosition: 45,
                source: .appleMusic
            ),
            NowPlayingItem(
                title: "Blinding Lights",
                artist: "The Weeknd",
                album: "After Hours",
                duration: 200,
                playbackPosition: 10,
                source: .spotify
            ),
            NowPlayingItem(
                title: "Bohemian Rhapsody",
                artist: "Queen",
                album: "A Night at the Opera",
                duration: 354,
                playbackPosition: 120,
                source: .browser
            )
        ]
        
        self.playlist = initialTracks ?? defaults
        if let first = self.playlist.first {
            self.currentPosition = first.playbackPosition
        }
    }
    
    public func fetchSnapshot() async -> NowPlayingItem? {
        lock.withLock {
            guard _isAvailable, !playlist.isEmpty else { return nil }
            let base = playlist[currentIndex]
            return NowPlayingItem(
                title: base.title,
                artist: base.artist,
                album: base.album,
                artworkURL: base.artworkURL,
                duration: base.duration,
                playbackPosition: currentPosition,
                source: base.source
            )
        }
    }
    
    public func fetchPlaybackState() async -> PlaybackState {
        lock.withLock {
            guard _isAvailable else { return .stopped }
            return _playbackState
        }
    }
    
    public func playPause() async throws {
        try lock.withLock {
            guard _isAvailable else {
                throw MusicProviderError.providerUnavailable(identifier)
            }
            guard _capabilities.contains(.playPause) else {
                throw MusicProviderError.unsupportedAction("playPause")
            }
            
            _playbackState = (_playbackState == .playing) ? .paused : .playing
        }
    }
    
    public func next() async throws {
        try lock.withLock {
            guard _isAvailable else {
                throw MusicProviderError.providerUnavailable(identifier)
            }
            guard _capabilities.contains(.skipNext) else {
                throw MusicProviderError.unsupportedAction("skipNext")
            }
            guard !playlist.isEmpty else { return }
            
            currentIndex = (currentIndex + 1) % playlist.count
            currentPosition = 0
            _playbackState = .playing
        }
    }
    
    public func previous() async throws {
        try lock.withLock {
            guard _isAvailable else {
                throw MusicProviderError.providerUnavailable(identifier)
            }
            guard _capabilities.contains(.skipPrevious) else {
                throw MusicProviderError.unsupportedAction("skipPrevious")
            }
            guard !playlist.isEmpty else { return }
            
            currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
            currentPosition = 0
            _playbackState = .playing
        }
    }
    
    // MARK: - Test Controls
    
    public func setAvailable(_ available: Bool) {
        lock.withLock {
            self._isAvailable = available
        }
    }
    
    public func setCapabilities(_ caps: MusicProviderCapabilities) {
        lock.withLock {
            self._capabilities = caps
        }
    }
    
    public func setPlaybackState(_ state: PlaybackState) {
        lock.withLock {
            self._playbackState = state
        }
    }
    
    public func advancePosition(by seconds: TimeInterval) {
        lock.withLock {
            guard !playlist.isEmpty else { return }
            let maxDuration = playlist[currentIndex].duration
            currentPosition = min(currentPosition + seconds, maxDuration)
        }
    }
    
    public func setTracks(_ tracks: [NowPlayingItem]) {
        lock.withLock {
            self.playlist = tracks
            self.currentIndex = 0
            self.currentPosition = tracks.first?.playbackPosition ?? 0
        }
    }
}
