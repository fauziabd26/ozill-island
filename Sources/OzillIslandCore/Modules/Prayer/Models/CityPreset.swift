import Foundation

public struct CityPreset: Identifiable, Hashable, Codable {
    public var id: String { name }
    public let name: String
    public let province: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    
    public init(name: String, province: String, latitude: Double, longitude: Double, timeZoneIdentifier: String = "Asia/Jakarta") {
        self.name = name
        self.province = province
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }
    
    public static let defaults: [CityPreset] = [
        CityPreset(name: "DKI Jakarta", province: "DKI Jakarta", latitude: -6.2088, longitude: 106.8456, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Surabaya", province: "Jawa Timur", latitude: -7.2575, longitude: 112.7521, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Bandung", province: "Jawa Barat", latitude: -6.9175, longitude: 107.6191, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Medan", province: "Sumatera Utara", latitude: 3.5952, longitude: 98.6722, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Semarang", province: "Jawa Tengah", latitude: -6.9667, longitude: 110.4167, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Yogyakarta", province: "DI Yogyakarta", latitude: -7.7956, longitude: 110.3695, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Makassar", province: "Sulawesi Selatan", latitude: -5.1477, longitude: 119.4327, timeZoneIdentifier: "Asia/Makassar"),
        CityPreset(name: "Denpasar", province: "Bali", latitude: -8.6705, longitude: 115.2126, timeZoneIdentifier: "Asia/Makassar"),
        CityPreset(name: "Palembang", province: "Sumatera Selatan", latitude: -2.9761, longitude: 104.7754, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Balikpapan", province: "Kalimantan Timur", latitude: -1.2379, longitude: 116.8289, timeZoneIdentifier: "Asia/Makassar"),
        CityPreset(name: "Banjarmasin", province: "Kalimantan Selatan", latitude: -3.3194, longitude: 114.5908, timeZoneIdentifier: "Asia/Makassar"),
        CityPreset(name: "Banda Aceh", province: "Aceh", latitude: 5.5483, longitude: 95.3238, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Padang", province: "Sumatera Barat", latitude: -0.9471, longitude: 100.4172, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Pekanbaru", province: "Riau", latitude: 0.5071, longitude: 101.4478, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Jayapura", province: "Papua", latitude: -2.5337, longitude: 140.7181, timeZoneIdentifier: "Asia/Jayapura")
    ]
    
    public static var defaultCity: CityPreset {
        defaults[0] // Jakarta
    }
}
