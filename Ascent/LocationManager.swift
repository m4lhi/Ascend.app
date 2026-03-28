import Foundation
import CoreLocation
import CoreMotion
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()

    @Published var userLocation: CLLocation?

    // === NEU: DIE LIVE-TRACKING DATEN === // [cite: 2026-03-07]
    @Published var isRecording = false
    @Published var route: [CLLocation] = [] // Die Brotkrümel-Spur
    private(set) var rawRoute: [CLLocation] = [] // Preserved raw GPS fixes — never overwritten

    @Published var distanceMeters: Double = 0.0
    @Published var ascentMeters: Double = 0.0
    @Published var currentAltitude: Double = 0.0
    @Published var currentSpeed: Double = 0.0 // in km/h

    // CMAltimeter state
    private let isAltimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    private var altimeterRelativeAltitude: Double? = nil
    private var altimeterBaseline: Double? = nil    // GPS altitude at session start

    // Smoothing buffer (window: 5 samples)
    private var altitudeBuffer: [Double] = []
    private let smoothingWindow = 5

    // Noise threshold state (5 m in 10 s window)
    private var windowStartTime: Date = Date()
    private var windowStartAltitude: Double? = nil
    private let noiseThresholdMeters: Double = 5.0
    private let noiseWindowSeconds: Double = 10.0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // === DER ANTI-LAG FIX ===
        // Das GPS feuert jetzt nur noch, wenn man sich wirklich 5 Meter bewegt hat.
        manager.distanceFilter = 5
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    // === NEU: START & STOP LOGIK === // [cite: 2026-03-07]
    func startRecording() {
        isRecording = true
        route.removeAll()
        rawRoute.removeAll()
        distanceMeters = 0
        ascentMeters = 0
        altitudeBuffer = []
        altimeterRelativeAltitude = nil
        altimeterBaseline = nil
        windowStartAltitude = nil
        windowStartTime = Date()

        if isAltimeterAvailable {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.altimeterRelativeAltitude = data.relativeAltitude.doubleValue
            }
        }
    }

    func stopRecording() {
        isRecording = false
        if isAltimeterAvailable { altimeter.stopRelativeAltitudeUpdates() }
        applyPostHocSmoothing()
    }

    // Returns the best available altitude for a GPS fix.
    // Uses barometric (CMAltimeter) when available; falls back to GPS altitude.
    private func effectiveAltitude(for location: CLLocation) -> Double {
        if isAltimeterAvailable,
           let relAlt = altimeterRelativeAltitude,
           let baseline = altimeterBaseline {
            return baseline + relAlt
        }
        return location.altitude
    }

    // Pushes a sample into the 5-sample moving-average buffer and returns the smoothed value.
    private func smoothed(altitude: Double) -> Double {
        altitudeBuffer.append(altitude)
        if altitudeBuffer.count > smoothingWindow { altitudeBuffer.removeFirst() }
        return altitudeBuffer.reduce(0, +) / Double(altitudeBuffer.count)
    }

    // Recalculates ascentMeters using a 5-sample moving average over the preserved raw GPS trail.
    // rawRoute is never modified here — it always holds the original GPS fixes.
    private func applyPostHocSmoothing() {
        guard rawRoute.count >= 2 else { return }
        let rawAltitudes = rawRoute.map { $0.altitude }
        var smoothedAltitudes: [Double] = []
        for i in 0..<rawAltitudes.count {
            let start = max(0, i - smoothingWindow + 1)
            let window = rawAltitudes[start...i]
            smoothedAltitudes.append(window.reduce(0, +) / Double(window.count))
        }
        var smoothedGain: Double = 0
        for i in 1..<smoothedAltitudes.count {
            let delta = smoothedAltitudes[i] - smoothedAltitudes[i - 1]
            if delta > 0 { smoothedGain += delta }
        }
        ascentMeters = smoothedGain
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        currentSpeed = max(location.speed * 3.6, 0)

        if isRecording {
            rawRoute.append(location) // always preserve the raw GPS fix

            // Anchor the altimeter baseline to the first GPS fix of this session
            if altimeterBaseline == nil { altimeterBaseline = location.altitude }

            let effAlt = effectiveAltitude(for: location)
            let smoothAlt = smoothed(altitude: effAlt)
            currentAltitude = smoothAlt

            // Noise threshold: only accumulate gain if ≥ 5 m within a 10 s window
            if windowStartAltitude == nil {
                windowStartAltitude = smoothAlt
                windowStartTime = Date()
            } else {
                let now = Date()
                if now.timeIntervalSince(windowStartTime) >= noiseWindowSeconds {
                    let windowDelta = smoothAlt - windowStartAltitude!
                    if windowDelta >= noiseThresholdMeters {
                        ascentMeters += windowDelta
                    }
                    windowStartAltitude = smoothAlt
                    windowStartTime = now
                }
            }

            if let lastLocation = route.last {
                distanceMeters += location.distance(from: lastLocation)
            }
            route.append(location)
        } else {
            currentAltitude = location.altitude
        }
    }
}
