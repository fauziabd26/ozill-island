import Foundation
import AppKit

/// Adapter Microsoft Edge (Chromium) untuk deteksi dan kontrol tab YouTube & YouTube Music.
public final class EdgeMusicAdapter: BrowserAdapter, @unchecked Sendable {
    public let browserBundleIdentifier: String = "com.microsoft.edgemac"
    public let browserDisplayName: String = "Microsoft Edge"
    
    public var supportedCapabilities: MusicProviderCapabilities {
        [.playPause, .skipNext, .skipPrevious, .seek]
    }
    
    public init() {}
    
    public func detectMediaSessions() async -> [BrowserMediaSession] {
        guard isBrowserRunning else { return [] }
        
        let script = """
        tell application "Microsoft Edge"
            set sessionList to {}
            set winIndex to 0
            repeat with w in windows
                set winIndex to winIndex + 1
                set tabIndex to 0
                repeat with t in tabs of w
                    set tabIndex to tabIndex + 1
                    set u to URL of t
                    if u contains "youtube.com" or u contains "youtu.be" then
                        set isYTM to (u contains "music.youtube.com")
                        set jsScript to "JSON.stringify((function() { " & ¬
                            "var v = document.querySelector('video'); " & ¬
                            "if (!v) return null; " & ¬
                            "var title = document.title; " & ¬
                            "var artist = ''; " & ¬
                            "var isMusic = window.location.hostname.indexOf('music.youtube.com') !== -1; " & ¬
                            "var art = ''; " & ¬
                            "if (isMusic) { " & ¬
                            "   var titleEl = document.querySelector('ytmusic-player-bar .title'); " & ¬
                            "   if (titleEl) title = titleEl.textContent.trim(); " & ¬
                            "   var bylineEl = document.querySelector('ytmusic-player-bar .byline'); " & ¬
                            "   if (bylineEl) artist = bylineEl.textContent.trim(); " & ¬
                            "   var imgEl = document.querySelector('ytmusic-player-bar .image, ytmusic-player-bar img'); " & ¬
                            "   if (imgEl && imgEl.src) art = imgEl.src; " & ¬
                            "} else { " & ¬
                            "   var chanEl = document.querySelector('#owner #channel-name a, #upload-info #channel-name a'); " & ¬
                            "   if (chanEl) artist = chanEl.textContent.trim(); " & ¬
                            "} " & ¬
                            "return { " & ¬
                            "   title: title, " & ¬
                            "   artist: artist, " & ¬
                            "   artwork: art, " & ¬
                            "   currentTime: v.currentTime, " & ¬
                            "   duration: isNaN(v.duration) ? 0 : v.duration, " & ¬
                            "   paused: v.paused " & ¬
                            "}; " & ¬
                            "})());"
                        
                        try
                            set jsRes to execute t javascript jsScript
                            if jsRes is not missing value and jsRes is not "" and jsRes is not "null" then
                                set end of sessionList to (winIndex as string) & ":::" & (tabIndex as string) & ":::" & u & ":::" & (isYTM as string) & ":::" & jsRes
                            end if
                        on error
                        end try
                    end if
                end repeat
            end repeat
            return sessionList
        end tell
        """
        
        let (success, output) = await ScriptBridge.executeAppleScript(script, timeout: 1.5)
        guard success, !output.isEmpty else { return [] }
        
        return parseSessions(from: output)
    }
    
    public func playPause(sessionId: String) async throws {
        let (winIndex, tabIndex) = try parseSessionCoordinates(sessionId)
        let script = """
        tell application "Microsoft Edge"
            try
                set t to tab \(tabIndex) of window \(winIndex)
                execute t javascript "var v = document.querySelector('video'); if (v) { v.paused ? v.play() : v.pause(); }"
            on error err
                error err
            end try
        end tell
        """
        let (success, err) = await ScriptBridge.executeAppleScript(script)
        if !success {
            throw MusicProviderError.executionFailed(err)
        }
    }
    
    public func next(sessionId: String) async throws {
        let (winIndex, tabIndex) = try parseSessionCoordinates(sessionId)
        let script = """
        tell application "Microsoft Edge"
            try
                set t to tab \(tabIndex) of window \(winIndex)
                execute t javascript "var nextBtn = document.querySelector('.ytp-next-button, ytmusic-player-bar .next-button'); if (nextBtn) { nextBtn.click(); } else { var v = document.querySelector('video'); if (v) v.currentTime = v.duration; }"
            end try
        end tell
        """
        _ = await ScriptBridge.executeAppleScript(script)
    }
    
    public func previous(sessionId: String) async throws {
        let (winIndex, tabIndex) = try parseSessionCoordinates(sessionId)
        let script = """
        tell application "Microsoft Edge"
            try
                set t to tab \(tabIndex) of window \(winIndex)
                execute t javascript "var prevBtn = document.querySelector('.ytp-prev-button, ytmusic-player-bar .previous-button'); if (prevBtn) { prevBtn.click(); } else { var v = document.querySelector('video'); if (v) v.currentTime = 0; }"
            end try
        end tell
        """
        _ = await ScriptBridge.executeAppleScript(script)
    }
    
    public func seek(to seconds: TimeInterval, sessionId: String) async throws {
        let (winIndex, tabIndex) = try parseSessionCoordinates(sessionId)
        let script = """
        tell application "Microsoft Edge"
            try
                set t to tab \(tabIndex) of window \(winIndex)
                execute t javascript "var v = document.querySelector('video'); if (v) { v.currentTime = \(seconds); }"
            end try
        end tell
        """
        _ = await ScriptBridge.executeAppleScript(script)
    }
    
    private func parseSessions(from output: String) -> [BrowserMediaSession] {
        var sessions: [BrowserMediaSession] = []
        let rawItems = output.components(separatedBy: ", ")
        
        for item in rawItems {
            let parts = item.components(separatedBy: ":::")
            guard parts.count >= 5 else { continue }
            
            let winIdx = parts[0]
            let tabIdx = parts[1]
            let url = parts[2]
            let isYTM = parts[3].lowercased() == "true"
            let jsonString = parts[4]
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }
            
            var title = dict["title"] as? String ?? "YouTube Media"
            title = title.replacingOccurrences(of: " - YouTube", with: "")
                         .replacingOccurrences(of: " - YouTube Music", with: "")
            
            let artist = dict["artist"] as? String ?? (isYTM ? "YouTube Music" : "YouTube")
            let currentTime = dict["currentTime"] as? TimeInterval ?? 0
            let duration = dict["duration"] as? TimeInterval ?? 0
            let paused = dict["paused"] as? Bool ?? true
            
            let rawArtwork = dict["artwork"] as? String
            let thumbnailURL = (rawArtwork != nil && !rawArtwork!.isEmpty) ? rawArtwork : BrowserMediaHelper.extractYouTubeThumbnail(from: url)
            let artworkURL = thumbnailURL.flatMap { URL(string: $0) }
            
            let sessionId = "edge::\(winIdx)::\(tabIdx)"
            let source: MediaSourceType = isYTM ? .youtubeMusic : .browser
            
            let nowPlaying = NowPlayingItem(
                title: title.isEmpty ? "YouTube Media" : title,
                artist: artist.isEmpty ? (isYTM ? "YouTube Music" : "YouTube") : artist,
                album: browserDisplayName,
                artworkURL: artworkURL,
                duration: duration,
                playbackPosition: currentTime,
                source: source
            )
            
            let session = BrowserMediaSession(
                id: sessionId,
                browserBundleId: browserBundleIdentifier,
                browserName: browserDisplayName,
                tabTitle: title,
                urlString: url,
                nowPlaying: nowPlaying,
                isPlaying: !paused,
                isYouTube: !isYTM,
                isYouTubeMusic: isYTM
            )
            sessions.append(session)
        }
        
        return sessions
    }
    
    private func parseSessionCoordinates(_ sessionId: String) throws -> (Int, Int) {
        let parts = sessionId.components(separatedBy: "::")
        guard parts.count == 3,
              let win = Int(parts[1]),
              let tab = Int(parts[2]) else {
            throw MusicProviderError.unsupportedAction("Invalid session identifier: \(sessionId)")
        }
        return (win, tab)
    }
}
