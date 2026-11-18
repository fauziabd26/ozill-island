import Foundation

/// Mode fungsional Island yang dipilih oleh IslandModeRouter berdasarkan prioritas modul aktif.
public enum IslandMode: String, CaseIterable, Sendable {
    case idle
    case prayer
    case music
    case split
    case banner
}
