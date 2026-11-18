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
    @Published public var authorizationStatus: CLAuthorizationStatus
    
    public override init() {
        // Load fallback hierarchy:
        // 1. Last Known Location
        // 2. Default City (Jakarta)
        if let savedData = UserDefaults.standard.data(forKey: lastLocationKey),
           let saved = try? JSONDecoder().decode(SavedLocation.self, from: savedData) {
            self.latitude = saved.latitude
            self.longitude = saved.longitude
            self.locationName = saved.name
            self.currentTimeZone = TimeZone(identifier: saved.timeZoneIdentifier) ?? .current
            self.statusMessage = "Lokasi tersimpan: \(saved.name)"
        } else {
            let defaultCity = CityPreset.defaultCity
            self.latitude = defaultCity.latitude
            self.longitude = defaultCity.longitude
            self.locationName = defaultCity.name
            self.currentTimeZone = TimeZone(identifier: defaultCity.timeZoneIdentifier) ?? .current
            self.statusMessage = "Lokasi default: \(defaultCity.name)"
        }
        
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    /// Meminta lokasi GPS sekali saja (single-shot, tidak menguras baterai)
    public func requestSingleLocation() {
        isLocating = true
        statusMessage = "Mendeteksi koordinat..."
        
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            fallbackToLastKnownOrPreset(reason: "Izin lokasi tidak diberikan")
        @unknown default:
            isLocating = false
            fallbackToLastKnownOrPreset(reason: "Status lokasi tidak diketahui")
        }
    }
    
    /// Mengatur lokasi manual berdasarkan preset kota
    public func setManualCity(_ city: CityPreset) {
        self.latitude = city.latitude
        self.longitude = city.longitude
        self.locationName = city.name
        self.currentTimeZone = TimeZone(identifier: city.timeZoneIdentifier) ?? .current
        self.statusMessage = "Kota: \(city.name)"
        
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
        if let savedData = UserDefaults.standard.data(forKey: lastLocationKey),
           let saved = try? JSONDecoder().decode(SavedLocation.self, from: savedData) {
            self.latitude = saved.latitude
            self.longitude = saved.longitude
            self.locationName = saved.name
            self.currentTimeZone = TimeZone(identifier: saved.timeZoneIdentifier) ?? .current
            self.statusMessage = "\(reason) (memakai lokasi tersimpan: \(saved.name))"
        } else {
            let def = CityPreset.defaultCity
            self.latitude = def.latitude
            self.longitude = def.longitude
            self.locationName = def.name
            self.currentTimeZone = TimeZone(identifier: def.timeZoneIdentifier) ?? .current
            self.statusMessage = "\(reason) (fallback: \(def.name))"
        }
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        self.isLocating = false
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Lokasi GPS"
                    self.locationName = city
                    if let tz = placemark.timeZone {
                        self.currentTimeZone = tz
                    }
                }
                self.statusMessage = "GPS aktif: \(self.locationName)"
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
            fallbackToLastKnownOrPreset(reason: "Izin lokasi ditolak")
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
            self.fallbackToLastKnownOrPreset(reason: "GPS gagal: \(error.localizedDescription)")
        }
    }
    
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthChange(status)
        }
    }
}
