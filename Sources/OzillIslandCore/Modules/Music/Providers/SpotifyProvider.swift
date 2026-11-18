import Foundation
import AppKit

/// Provider resmi untuk aplikasi Spotify di macOS melalui AppleScript bridge terisolasi.
public final class SpotifyProvider: MusicProvider, @unchecked Sendable {
    public let identifier: String = "org.ozill.provider.spotify"
    public let displayName: String = "Spotify"
    public let bundleIdentifier: String = "com.spotify.client"
    
    public var isAvailable: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }
    
    public var capabilities: MusicProviderCapabilities {
        [.playPause, .skipNext, .skipPrevious, .seek, .readArtwork]
    }
    
    public init() {}
    
    public func fetchSnapshot() async -> NowPlayingItem? {
        guard isAvailable else { return nil }
        
        let script = """
        tell application "Spotify"
            if it is running then
                set pState to (player state as string)
                if pState is not "stopped" then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDuration to (duration of current track) / 1000
                    set tPos to player position
                    set artUrl to artwork url of current track
                    return pState & ":::" & tName & ":::" & tArtist & ":::" & tAlbum & ":::" & (tDuration as string) & ":::" & (tPos as string) & ":::" & artUrl
                end if
            end if
        end tell
        """
        
        let (success, output) = await ScriptBridge.executeAppleScript(script, timeout: 1.5)
        guard success, !output.isEmpty else { return nil }
        
        let parts = output.components(separatedBy: ":::")
        guard parts.count >= 6 else { return nil }
        
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4]) ?? 0
        let position = Double(parts[5]) ?? 0
        let artworkURL = (parts.count > 6 && !parts[6].isEmpty) ? URL(string: parts[6]) : nil
        
        return NowPlayingItem(
            title: title,
            artist: artist,
            album: album.isEmpty ? nil : album,
            artworkURL: artworkURL,
            duration: duration,
            playbackPosition: position,
            source: .spotify
        )
    }
    
    public func fetchPlaybackState() async -> PlaybackState {
        guard isAvailable else { return .stopped }
        
        let script = """
        tell application "Spotify"
            if it is running then
                return (player state as string)
            end if
        end tell
        """
        
        let (success, output) = await ScriptBridge.executeAppleScript(script, timeout: 1.0)
        guard success else { return .unknown }
        
        switch output.lowercased() {
        case "playing": return .playing
        case "paused": return .paused
        case "stopped": return .stopped
        default: return .unknown
        }
    }
    
    public func playPause() async throws {
        guard isAvailable else {
            throw MusicProviderError.providerUnavailable("Spotify tidak sedang berjalan.")
        }
        let script = "tell application \"Spotify\" to playpause"
        let (success, err) = await ScriptBridge.executeAppleScript(script)
        if !success { throw MusicProviderError.executionFailed(err) }
    }
    
    public func next() async throws {
        guard isAvailable else {
            throw MusicProviderError.providerUnavailable("Spotify tidak sedang berjalan.")
        }
        let script = "tell application \"Spotify\" to next track"
        _ = await ScriptBridge.executeAppleScript(script)
    }
    
    public func previous() async throws {
        guard isAvailable else {
            throw MusicProviderError.providerUnavailable("Spotify tidak sedang berjalan.")
        }
        let script = "tell application \"Spotify\" to previous track"
        _ = await ScriptBridge.executeAppleScript(script)
    }
    
    public func seek(to seconds: TimeInterval) async throws {
        guard isAvailable else {
            throw MusicProviderError.providerUnavailable("Spotify tidak sedang berjalan.")
        }
        let script = "tell application \"Spotify\" to set player position to \(seconds)"
        _ = await ScriptBridge.executeAppleScript(script)
    }
}
