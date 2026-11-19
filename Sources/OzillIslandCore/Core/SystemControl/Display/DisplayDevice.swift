import Foundation
import CoreGraphics

/// Tipe jenis layar tampilan yang terhubung ke macOS.
public enum DisplayKind: String, Codable, Sendable {
    case builtIn
    case external
    case virtual
}

/// Representasi perangkat monitor / layar tampilan pada sistem macOS.
public struct DisplayDevice: Identifiable, Equatable, Hashable, Sendable {
    public let id: CGDirectDisplayID
    public let name: String
    public let kind: DisplayKind
    public let isMain: Bool
    public let canAdjustBrightness: Bool
    
    public init(
        id: CGDirectDisplayID,
        name: String,
        kind: DisplayKind,
        isMain: Bool,
        canAdjustBrightness: Bool
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isMain = isMain
        self.canAdjustBrightness = canAdjustBrightness
    }
}
