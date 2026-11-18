import Foundation
import AppKit

/// Adapter Mozilla Firefox.
/// Catatan teknis: AppleScript dictionary Firefox di macOS tidak mengekspos eksekusi DOM
/// maupun URL per tab secara sah tanpa extension khusus.
public final class FirefoxMusicAdapter: BrowserAdapter, @unchecked Sendable {
    public let browserBundleIdentifier: String = "org.mozilla.firefox"
    public let browserDisplayName: String = "Firefox"
    
    public var supportedCapabilities: MusicProviderCapabilities {
        // Kontrol dibatasi karena batasan kamus AppleScript Firefox
        []
    }
    
    public init() {}
    
    public func detectMediaSessions() async -> [BrowserMediaSession] {
        // Tanpa browser extension lokal, Firefox tidak dapat membaca metadata tab internal secara aman
        return []
    }
    
    public func playPause(sessionId: String) async throws {
        throw MusicProviderError.unsupportedAction("Firefox tidak mendukung injeksi skrip AppleScript tab internal.")
    }
    
    public func next(sessionId: String) async throws {
        throw MusicProviderError.unsupportedAction("Firefox tidak mendukung skip next tanpa browser extension.")
    }
    
    public func previous(sessionId: String) async throws {
        throw MusicProviderError.unsupportedAction("Firefox tidak mendukung skip previous tanpa browser extension.")
    }
    
    public func seek(to seconds: TimeInterval, sessionId: String) async throws {
        throw MusicProviderError.unsupportedAction("Firefox tidak mendukung seek.")
    }
}
