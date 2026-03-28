import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var userLocation: CLLocation?
    
    // === NEU: DIE LIVE-TRACKING DATEN === // [cite: 2026-03-07]
    @Published var isRecording = false
    @Published var route: [CLLocation] = [] // Die Brotkrümel-Spur
    
    @Published var distanceMeters: Double = 0.0
    @Published var ascentMeters: Double = 0.0
    @Published var currentAltitude: Double = 0.0
    @Published var currentSpeed: Double = 0.0 // in km/h
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // === DER ANTI-LAG FIX ===
        // Das GPS feuert jetzt nur noch, wenn man sich wirklich 5 Meter bewegt hat.
        // Das verhindert, dass die App im Hintergrund 10x pro Sekunde den Bildschirm neu lädt!
        manager.distanceFilter = 5
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    // === NEU: START & STOP LOGIK === // [cite: 2026-03-07]
    func startRecording() {
        isRecording = true
        route.removeAll() // Alte Route löschen
        distanceMeters = 0
        ascentMeters = 0
    }
    
    func stopRecording() {
        isRecording = false
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        
        // Aktuelle Höhe und Geschwindigkeit (von m/s in km/h umgerechnet)
        currentAltitude = location.altitude
        currentSpeed = max(location.speed * 3.6, 0)
        
        // Wenn die Aufnahme läuft, rechnen wir live mit! // [cite: 2026-03-07]
        if isRecording {
            if let lastLocation = route.last {
                // 1. Distanz addieren
                distanceMeters += location.distance(from: lastLocation)
                
                // 2. Höhenmeter addieren (nur wenn es bergauf geht!)
                let altDifference = location.altitude - lastLocation.altitude
                if altDifference > 0 {
                    ascentMeters += altDifference
                }
            }
            // 3. Neuen Brotkrümel auf den Boden werfen
            route.append(location)
        }
    }
}
