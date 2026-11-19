import Foundation
import CoreGraphics

/// Status ketersediaan pengaturan kecerahan layar.
public enum DisplayBrightnessStatus: Equatable, Sendable {
    case available
    case unsupported(reason: String)
    case error(String)
}

/// Model state independen yang merepresentasikan status kecerahan layar tampilan macOS.
public struct DisplayState: Equatable, Sendable {
    public var brightness: Float // Nilai ternormalisasi 0.0 ... 1.0
    public var status: DisplayBrightnessStatus
    public var activeDisplay: DisplayDevice?
    public var connectedDisplays: [DisplayDevice]
    
    public var isAvailable: Bool {
        status == .available && (activeDisplay?.canAdjustBrightness ?? false)
    }
    
    public init(
        brightness: Float = 0.5,
        status: DisplayBrightnessStatus = .available,
        activeDisplay: DisplayDevice? = nil,
        connectedDisplays: [DisplayDevice] = []
    ) {
        self.brightness = max(0.0, min(1.0, brightness))
        self.status = status
        self.activeDisplay = activeDisplay
        self.connectedDisplays = connectedDisplays
    }
}
