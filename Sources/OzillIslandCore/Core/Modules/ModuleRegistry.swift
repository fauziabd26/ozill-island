import Foundation

public enum ModuleRegistryError: Error, LocalizedError, Equatable {
    case duplicateModule(identifier: String)
    case moduleNotFound(identifier: String)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateModule(let id):
            return "Modul dengan pengenal '\(id)' sudah terdaftar di ModuleRegistry."
        case .moduleNotFound(let id):
            return "Modul dengan pengenal '\(id)' tidak ditemukan."
        }
    }
}

/// Single Source of Truth pengelola seluruh modul terdaftar dalam sistem OzillIsland.
@MainActor
public final class ModuleRegistry: ObservableObject {
    public static let shared = ModuleRegistry()
    
    @Published private(set) var registeredModules: [String: IslandModule] = [:]
    
    public init() {}
    
    /// Mendaftarkan modul baru ke dalam registry. Menolak jika identifier sudah terdaftar.
    public func register(_ module: IslandModule) throws {
        let id = module.identifier
        guard registeredModules[id] == nil else {
            throw ModuleRegistryError.duplicateModule(identifier: id)
        }
        registeredModules[id] = module
    }
    
    /// Menghapus modul dari registry jika diperlukan.
    @discardableResult
    public func unregister(identifier: String) -> IslandModule? {
        guard let module = registeredModules.removeValue(forKey: identifier) else {
            return nil
        }
        return module
    }
    
    /// Mengambil modul terdaftar berdasarkan identifier.
    public func module(for identifier: String) -> IslandModule? {
        return registeredModules[identifier]
    }
    
    /// Mengambil seluruh modul terdaftar yang sedang tersedia (isAvailable == true),
    /// diurutkan dari prioritas tertinggi ke terendah (Descending).
    public func availableModulesSortedByPriority() -> [IslandModule] {
        return registeredModules.values
            .filter { $0.isAvailable }
            .sorted {
                if $0.currentPriority == $1.currentPriority {
                    return $0.identifier < $1.identifier
                }
                return $0.currentPriority > $1.currentPriority
            }
    }
    
    /// Mengambil seluruh modul terdaftar diurutkan berdasarkan prioritas.
    public func allModulesSortedByPriority() -> [IslandModule] {
        return registeredModules.values
            .sorted {
                if $0.currentPriority == $1.currentPriority {
                    return $0.identifier < $1.identifier
                }
                return $0.currentPriority > $1.currentPriority
            }
    }
    
    /// Menghapus seluruh registrasi (berguna untuk test teardown).
    public func unregisterAll() {
        registeredModules.removeAll()
    }
    
    /// Jumlah modul yang terdaftar saat ini.
    public var count: Int {
        registeredModules.count
    }
}
