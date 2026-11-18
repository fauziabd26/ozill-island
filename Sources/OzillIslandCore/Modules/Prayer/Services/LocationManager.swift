import Foundation
import CoreLocation
import Combine

public struct SavedLocation: Codable {
    public let latitude: Double
    public let longitude: Double
    public let name: String
    public let timeZoneIdentifier: String
    
    public init(latitude: Double, longitude: Double, name: String, timeZoneIdentifier: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

@MainActor
public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    private let lastLocationKey = "OzillIsland_LastKnownLocation"
    
    @Published public var latitude: Double
    @Published public var longitude: Double
    @Published public var locationName: String
    @Published public var currentTimeZone: TimeZone
    @Published public var isLocating: Bool = false
    @Published public var statusMessage: String = "Siap"
    @Published public var isUsingOfflineFallback: Bool = false
    @Published public var authorizationStatus: CLAuthorizationStatus
    
    public override init() {
        // Hierarki Fallback:
        // 1. Lokasi Tersimpan Terakhir (UserDefaults)
        // 2. Default City (DKI Jakarta)
        if let savedData = UserDefaults.standard.data(forKey: lastLocationKey),
           let saved = try? JSONDecoder().decode(SavedLocation.self, from: savedData) {
            self.latitude = saved.latitude
            self.longitude = saved.longitude
            self.locationName = saved.name
            self.currentTimeZone = TimeZone(identifier: saved.timeZoneIdentifier) ?? .current
            self.statusMessage = "Lokasi tersimpan (Offline): \(saved.name)"
            self.isUsingOfflineFallback = true
        } else {
            let defaultCity = CityPreset.defaultCity
            self.latitude = defaultCity.latitude
            self.longitude = defaultCity.longitude
            self.locationName = defaultCity.name
            self.currentTimeZone = TimeZone(identifier: defaultCity.timeZoneIdentifier) ?? .current
            self.statusMessage = "Preset default (Offline): \(defaultCity.name)"
            self.isUsingOfflineFallback = true
        }
        
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    /// Meminta lokasi CoreLocation satu kali (single-shot, tidak tracking continuous)
    public func requestSingleLocation() {
        isLocating = true
        statusMessage = "Mendeteksi posisi via Layanan Lokasi macOS..."
        
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            fallbackToLastKnownOrPreset(reason: "Izin Layanan Lokasi belum diberikan")
        @unknown default:
            isLocating = false
            fallbackToLastKnownOrPreset(reason: "Status Layanan Lokasi tidak diketahui")
        }
    }
    
    /// Mengatur lokasi manual berdasarkan preset kota (100% Offline tanpa GPS/Wi-Fi)
    public func setManualCity(_ city: CityPreset) {
        self.latitude = city.latitude
        self.longitude = city.longitude
        self.locationName = city.name
        self.currentTimeZone = TimeZone(identifier: city.timeZoneIdentifier) ?? .current
        self.statusMessage = "Preset Kota (Offline): \(city.name)"
        self.isUsingOfflineFallback = true
        
        saveCurrentLocationLocally()
    }
    
    public func saveCurrentLocationLocally() {
        let saved = SavedLocation(
            latitude: latitude,
            longitude: longitude,
            name: locationName,
            timeZoneIdentifier: currentTimeZone.identifier
        )
        if let encoded = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(encoded, forKey: lastLocationKey)
        }
    }
    
    public func fallbackToLastKnownOrPreset(reason: String) {
        isUsingOfflineFallback = true
        if let savedData = UserDefaults.standard.data(forKey: lastLocationKey),
           let saved = try? JSONDecoder().decode(SavedLocation.self, from: savedData) {
            self.latitude = saved.latitude
            self.longitude = saved.longitude
            self.locationName = saved.name
            self.currentTimeZone = TimeZone(identifier: saved.timeZoneIdentifier) ?? .current
            self.statusMessage = "\(reason) → Memakai lokasi tersimpan: \(saved.name)"
        } else {
            let def = CityPreset.defaultCity
            self.latitude = def.latitude
            self.longitude = def.longitude
            self.locationName = def.name
            self.currentTimeZone = TimeZone(identifier: def.timeZoneIdentifier) ?? .current
            self.statusMessage = "\(reason) → Fallback: \(def.name)"
        }
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        self.isLocating = false
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.isUsingOfflineFallback = false
        
        // Reverse geocoding (memerlukan koneksi jaringan macOS)
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Posisi Terdeteksi"
                    self.locationName = city
                    if let tz = placemark.timeZone {
                        self.currentTimeZone = tz
                    }
                }
                self.statusMessage = "Lokasi aktif (Layanan macOS): \(self.locationName)"
                self.saveCurrentLocationLocally()
            }
        }
    }
    
    private func handleAuthChange(_ status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        case .authorized, .authorizedAlways:
            requestSingleLocation()
        case .denied, .restricted:
            isLocating = false
            fallbackToLastKnownOrPreset(reason: "Izin lokasi tidak diberikan")
        default:
            break
        }
    }
    
    // MARK: - CLLocationManagerDelegate (Nonisolated for Swift Concurrency)
    
    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.handleLocationUpdate(location)
        }
    }
    
    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.fallbackToLastKnownOrPreset(reason: "Gagal mendeteksi via jaringan: \(error.localizedDescription)")
        }
    }
    
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthChange(status)
        }
    }
}
