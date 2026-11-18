import Foundation

/// Prioritas hierarkis modul dalam sistem IslandModeRouter.
/// Nilai integer lebih tinggi memiliki hak lebih utama untuk ditampilkan di Island.
public struct ModulePriority: Comparable, Equatable, Hashable, Sendable {
    public let rawValue: Int
    
    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static func < (lhs: ModulePriority, rhs: ModulePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    /// Event darurat/kritis sistem (misal: adzan berkumandang, baterai sekarat < 5%, alarm timer bunyi).
    public static let critical = ModulePriority(100)
    
    /// Media yang sedang aktif berputar atau proses intensif (misal: musik playing, podcast, stopwatch aktif).
    public static let activeMedia = ModulePriority(80)
    
    /// Event informasi penting terdekat (misal: 10 menit menuju shalat, 5 menit menuju meeting).
    public static let upcomingEvent = ModulePriority(60)
    
    /// Tampilan standby default sesuai preferensi pengguna.
    public static let standby = ModulePriority(40)
    
    /// Modul background / pasif.
    public static let background = ModulePriority(20)
}
