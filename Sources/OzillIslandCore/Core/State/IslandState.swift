import Foundation

/// State visual antarmuka Island: ukuran dan mode tampil panel floating.
public enum IslandState: String, CaseIterable, Sendable {
    case collapsed
    case expanded
    case settings
}
