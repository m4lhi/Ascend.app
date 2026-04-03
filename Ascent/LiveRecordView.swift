import SwiftUI
import MapKit
import Combine
import CoreLocation
import CoreMotion
import Charts
import PhotosUI

// =========================================
// === DATEI: LiveRecordView.swift ===
// === Tracker mit Smartem Gipfel-Check ===
// =========================================

// MARK: - Location Manager
class LiveGPSManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()

    @Published var distance: Double = 0.0
    @Published var elevationGain: Double = 0.0
    @Published var currentLocation: CLLocation?
    @Published var routePoints: [CLLocationCoordinate2D] = []
    
    @Published var isRecording: Bool = false
    
    private(set) var rawRoute: [CLLocation] = []
    private static let maxRawRoutePoints = 5000
    private var lastLocation: CLLocation?

    private let isAltimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    private var altimeterRelativeAltitude: Double? = nil
    private var altimeterBaseline: Double? = nil
    private var altimeterStarted = false

    private var altitudeBuffer: [Double] = []
    private let smoothingWindow = 5

    private var windowStartTime: Date = Date()
    private var windowStartAltitude: Double? = nil
    private let noiseThresholdMeters: Double = 1.5
    private let noiseWindowSeconds: Double = 10.0

    @Published var isAutoPaused: Bool = false
    @Published var pauseLog: [PauseEntry] = []
    @Published var totalPauseDuration: TimeInterval = 0

    private var lowSpeedStart: Date? = nil
    private let autoPauseSpeedThreshold: Double = 0.2
    private let autoPauseDelay: TimeInterval = 10.0

    private var recentLocations: [CLLocation] = []
    private let driftBufferSize = 10
    private let driftStddevThreshold: Double = 5.0

    private var currentPauseStart: Date? = nil
    private var currentPauseCoordinate: CLLocationCoordinate2D? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.requestWhenInUseAuthorization()
        
        // 🟢 Karte soll User sofort tracken können
        manager.startUpdatingLocation()
    }

    func startTracking() {
        isRecording = true
        manager.startUpdatingLocation()
        lastLocation = nil
        if isAltimeterAvailable && !altimeterStarted {
            altimeterStarted = true
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.altimeterRelativeAltitude = data.relativeAltitude.doubleValue
            }
        }
    }

    func stopTracking() {
        isRecording = false
        manager.stopUpdatingLocation()
    }

    func logManualPause() {
        if isAutoPaused {
            closeCurrentPause(isAutomatic: true)
            isAutoPaused = false
        }
        currentPauseStart = Date()
        currentPauseCoordinate = currentLocation?.coordinate
    }

    func logManualResume() {
        closeCurrentPause(isAutomatic: false)
        lowSpeedStart = nil
        recentLocations.removeAll()
    }

    func finalizeSession() {
        if isAutoPaused {
            closeCurrentPause(isAutomatic: true)
            isAutoPaused = false
        } else if currentPauseStart != nil {
            closeCurrentPause(isAutomatic: false)
        }

        if isAltimeterAvailable {
            altimeter.stopRelativeAltitudeUpdates()
            altimeterStarted = false
        }
        applyPostHocSmoothing()
    }

    private func closeCurrentPause(isAutomatic: Bool) {
        guard let start = currentPauseStart else { return }
        let coord = currentPauseCoordinate ?? CLLocationCoordinate2D()
        let entry = PauseEntry(
            id: UUID(),
            startTime: start,
            endTime: Date(),
            latitude: coord.latitude,
            longitude: coord.longitude,
            isAutomatic: isAutomatic
        )
        pauseLog.append(entry)
        totalPauseDuration += entry.duration
        currentPauseStart = nil
        currentPauseCoordinate = nil
    }

    private func effectiveAltitude(for location: CLLocation) -> Double {
        if isAltimeterAvailable,
           let relAlt = altimeterRelativeAltitude,
           let baseline = altimeterBaseline {
            return baseline + relAlt
        }
        return location.altitude
    }

    private func smoothed(altitude: Double) -> Double {
        altitudeBuffer.append(altitude)
        if altitudeBuffer.count > smoothingWindow { altitudeBuffer.removeFirst() }
        return altitudeBuffer.reduce(0, +) / Double(altitudeBuffer.count)
    }

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
        elevationGain = smoothedGain
    }

    private func isStationary(speed speedKmh: Double) -> Bool {
        if recentLocations.count >= driftBufferSize {
            let stddev = locationStddev(recentLocations.suffix(driftBufferSize))
            if stddev < driftStddevThreshold { return true }
        }
        return speedKmh < autoPauseSpeedThreshold
    }

    private func locationStddev(_ locations: ArraySlice<CLLocation>) -> Double {
        let count = Double(locations.count)
        guard count > 0 else { return 0 }
        let meanLat = locations.reduce(0.0) { $0 + $1.coordinate.latitude } / count
        let meanLon = locations.reduce(0.0) { $0 + $1.coordinate.longitude } / count
        let centroid = CLLocation(latitude: meanLat, longitude: meanLon)
        let distances = locations.map { $0.distance(from: centroid) }
        let meanDist = distances.reduce(0.0, +) / count
        let variance = distances.reduce(0.0) { $0 + ($1 - meanDist) * ($1 - meanDist) } / count
        return sqrt(variance)
    }

    private func enterAutoPause(at location: CLLocation) {
        isAutoPaused = true
        currentPauseStart = Date()
        currentPauseCoordinate = location.coordinate
    }

    private func exitAutoPause() {
        closeCurrentPause(isAutomatic: true)
        isAutoPaused = false
        lastLocation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        currentLocation = newLocation

        // 🟢 Zählt nur Höhenmeter, wenn isRecording = true
        guard isRecording else { return }

        recentLocations.append(newLocation)
        if recentLocations.count > driftBufferSize { recentLocations.removeFirst() }

        let speedKmh = max(newLocation.speed * 3.6, 0)

        if isAutoPaused {
            if speedKmh >= autoPauseSpeedThreshold {
                lowSpeedStart = nil
                exitAutoPause()
            }
        } else {
            let stationary = isStationary(speed: speedKmh)
            if stationary {
                if lowSpeedStart == nil {
                    lowSpeedStart = Date()
                } else if Date().timeIntervalSince(lowSpeedStart!) >= autoPauseDelay {
                    enterAutoPause(at: newLocation)
                }
            } else {
                lowSpeedStart = nil
            }
        }

        guard !isAutoPaused else { return }

        routePoints.append(newLocation.coordinate)
        rawRoute.append(newLocation)
        // Cap rawRoute to prevent unbounded memory growth on long hikes
        if rawRoute.count > Self.maxRawRoutePoints {
            rawRoute.removeFirst(rawRoute.count - Self.maxRawRoutePoints)
        }

        if altimeterBaseline == nil { altimeterBaseline = newLocation.altitude }

        let effAlt = effectiveAltitude(for: newLocation)
        let smoothAlt = smoothed(altitude: effAlt)

        if windowStartAltitude == nil {
            windowStartAltitude = smoothAlt
            windowStartTime = Date()
        } else {
            let now = Date()
            if now.timeIntervalSince(windowStartTime) >= noiseWindowSeconds {
                let windowDelta = smoothAlt - windowStartAltitude!
                if windowDelta >= noiseThresholdMeters {
                    elevationGain += windowDelta
                }
                windowStartAltitude = smoothAlt
                windowStartTime = now
            }
        }

        if let last = lastLocation {
            distance += newLocation.distance(from: last)
        }
        lastLocation = newLocation
    }
}

// =========================================
// === REDESIGNED: Premium Tracker UI ===
// =========================================

struct LiveRecordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var targetMountain: Mountain?

    @StateObject private var gpsManager = LiveGPSManager()
    @State private var timeElapsed: Int = 0
    @State private var isRunning: Bool = false
    @State private var blinkToggle: Bool = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var cameraPosition: MapCameraPosition

    @State private var showSaveForm = false
    @State private var showElevationProfile = false
    @State private var panelCollapsed = false
    @State private var sliderResetToken = UUID()
    
    // 🟢 Speichert die berechneten Routen
    @State private var appleApproachRoute: [CLLocationCoordinate2D]? = nil
    @State private var offlineAscentRoute: [CLLocationCoordinate2D]? = nil
    @State private var fallbackRoute: [CLLocationCoordinate2D]? = nil
    
    @State private var interceptIndex: Int = 0
    @State private var closestRouteIndex: Int? = nil

    @State private var hasCalculatedRoute = false
    @State private var isTooFarForRoute = false

    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)
    
    init(targetMountain: Mountain?) {
        self.targetMountain = targetMountain
        
        // 🟢 Wenn ein Berg da ist, zentriere direkt darauf, ansonsten nutze .automatic
        if let target = targetMountain, let lat = target.latitude, let lon = target.longitude {
            _cameraPosition = State(initialValue: .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distance: 15000)))
        } else {
            _cameraPosition = State(initialValue: .automatic)
        }
    }

    private var elevationProgress: Double {
        guard gpsManager.elevationGain > 0 else { return 0 }
        if let target = targetMountain {
            return min(gpsManager.elevationGain / Double(target.elevation), 1.0)
        }
        return gpsManager.elevationGain.truncatingRemainder(dividingBy: 500.0) / 500.0
    }

    private var liveXP: Int { 100 + Int(gpsManager.elevationGain) }

    private var statusLabel: String {
        if isRunning && gpsManager.isAutoPaused { return "AUTO-PAUSED" }
        if isRunning { return "RECORDING" }
        if timeElapsed > 0 { return "PAUSED" }
        return targetMountain?.name.uppercased() ?? "READY"
    }

    private var statusDotColor: Color {
        if gpsManager.isAutoPaused { return .orange }
        if isRunning { return .red }
        return .gray
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // === LAYER 1: Map ===
            Map(position: $cameraPosition, bounds: MapCameraBounds(maximumDistance: 150_000)) {
                UserAnnotation()
                
                // 🟢 Zieht den dynamischen Zustieg (Approach) als durchgehende graue Linie (vorher gestrichelt)
                if let approach = appleApproachRoute {
                    MapPolyline(coordinates: approach)
                        .stroke(.gray.opacity(0.8), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                } else if let fallback = fallbackRoute {
                    MapPolyline(coordinates: fallback)
                        .stroke(.gray.opacity(0.8), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                
                // 🟢 Zeichnet die Offline Ascent Polyline (z.T. ignoriert, z.T. aktiv)
                if let routeCoords = offlineAscentRoute, routeCoords.count > 1 {
                    
                    let safeIntercept = min(max(0, interceptIndex), routeCoords.count - 1)
                    let safeActiveStart = min(max(safeIntercept, closestRouteIndex ?? safeIntercept), routeCoords.count - 1)
                    
                    // Der ignorierte untere Teil (vor dem Interception Point)
                    if safeIntercept > 0 {
                        MapPolyline(coordinates: Array(routeCoords[0...safeIntercept]))
                            .stroke(.gray.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                    
                    // Das Stück vom Interception-Point bis zur aktuellen User-Position (bereits gelaufen / grau)
                    if safeActiveStart > safeIntercept {
                        MapPolyline(coordinates: Array(routeCoords[safeIntercept...safeActiveStart]))
                            .stroke(.gray.opacity(0.6), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    
                    // Das restliche, noch zu laufende Stück in die Zukunft (Sattes Cyan)
                    if safeActiveStart < routeCoords.count - 1 {
                        MapPolyline(coordinates: Array(routeCoords[safeActiveStart...]))
                            .stroke(.cyan, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }
                
                // 🟢 Zeigt den Ziel-Marker auf dem Berg
                if let target = targetMountain, let lat = target.latitude, let lon = target.longitude {
                    Marker(target.name, systemImage: "mountain.2.fill", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        .tint(gold)
                        
                    // 🟢 Zeigt optional das Trailhead-Startsymbol (den Parkplatz)
                    if let routes = target.routes, let first = routes.first {
                        let tLat = first.start_lat
                        let tLon = first.start_lon
                        Annotation("Trailhead", coordinate: CLLocationCoordinate2D(latitude: tLat, longitude: tLon)) {
                            Image(systemName: "figure.walk.arrival")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(gold)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 3)
                        }
                    }
                }
                
                // 🟢 Zeigt die Linie an, die du tatsächlich gelaufen bist
                if !gpsManager.routePoints.isEmpty {
                    MapPolyline(coordinates: gpsManager.routePoints)
                        .stroke(gold, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea()
            .onChange(of: gpsManager.currentLocation) { _, newLoc in
                guard let loc = newLoc else { return }
                
                // 🟢 Off-Route Detection: Snapping & Splitting update
                updateClosestRouteIndex(to: loc.coordinate)
                
                guard let target = targetMountain, !hasCalculatedRoute,
                      let targetLat = target.latitude, let targetLon = target.longitude else { return }
                
                hasCalculatedRoute = true
                withAnimation { self.isTooFarForRoute = false }
                calculateRouteToMountain(from: loc.coordinate, to: CLLocationCoordinate2D(latitude: targetLat, longitude: targetLon))
            }

            // === LAYER 2: Lightening overlay ===
            Color.white.opacity(0.4).ignoresSafeArea()

            // === LAYER 3: Top gradient ===
            VStack {
                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.5), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200).ignoresSafeArea()
                Spacer()
            }

            // === LAYER 4: Bottom gradient ===
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .white.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 300).ignoresSafeArea()
            }
            
            // === LAYER 5: Map Controls (Buttons) ===
            // 🟢 Die Buttons sind jetzt sicher OBEN RECHTS platziert
            VStack(spacing: 14) {
                if targetMountain != nil {
                    Button(action: viewFullRoute) {
                        Image(systemName: "map")
                            .font(.system(size: 20, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                }
                
                Button(action: centerOnUser) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 20, design: .rounded))
                        .foregroundColor(gold)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 140)

            // === LAYER 6: Content ===
            VStack(spacing: 0) {
                topBar
                Spacer()
                dataPanel
            }
            
            // 🟢 Warnung, wenn User zu weit entfernt ist
            if isTooFarForRoute && !isRunning {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("You are too far away for route guidance.")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.bottom, 220)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
        .onReceive(timer) { _ in
            blinkToggle.toggle()
            if isRunning && !gpsManager.isAutoPaused { timeElapsed += 1 }
        }
        .sheet(isPresented: $showSaveForm, onDismiss: {
            sliderResetToken = UUID()
        }) {
            MissionSaveView(
                targetMountain: targetMountain,
                elevationMeters: Int(gpsManager.elevationGain),
                durationSeconds: TimeInterval(timeElapsed),
                distanceKm: gpsManager.distance / 1000.0,
                pauseLog: gpsManager.pauseLog,
                totalPauseDuration: gpsManager.totalPauseDuration,
                onDismissTracker: { dismiss() }
            )
        }
    }

    // 🟢 BUTTON-FUNKTION: Zurück auf User zoomen
    private func centerOnUser() {
        HapticManager.shared.light()
        if let userLoc = gpsManager.currentLocation {
            withAnimation(.easeInOut(duration: 1.0)) {
                cameraPosition = .camera(MapCamera(centerCoordinate: userLoc.coordinate, distance: 3000))
            }
        }
    }
    
    // 🟢 HILFS-FUNKTION: Sucht den nächsten Routenpunkt für das Snapping (Split Rendering)
    private func updateClosestRouteIndex(to coord: CLLocationCoordinate2D) {
        guard let route = offlineAscentRoute, !route.isEmpty else { return }
        let userLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        
        var minDistance: CLLocationDistance = .infinity
        let startIdx = min(max(0, interceptIndex), route.count - 1)
        var minIndex: Int = startIdx
        
        for i in startIdx..<route.count {
            let routePt = route[i]
            let pointLoc = CLLocation(latitude: routePt.latitude, longitude: routePt.longitude)
            let dist = userLoc.distance(from: pointLoc)
            if dist < minDistance {
                minDistance = dist
                minIndex = i
            }
        }
        
        // Regel: Nur Snappen, wenn wir weniger als ~250m von der Linie entfernt sind.
        if minDistance < 250 {
            withAnimation(.easeInOut(duration: 0.5)) {
                if let current = closestRouteIndex, minIndex > current {
                    closestRouteIndex = minIndex
                } else if closestRouteIndex == nil {
                    closestRouteIndex = max(minIndex, startIdx)
                }
            }
        }
    }

    // 🟢 BUTTON-FUNKTION: Ganze Route übersichtlich anzeigen
    private func viewFullRoute() {
        HapticManager.shared.light()
        
        var allPoints: [CLLocationCoordinate2D] = []
        if let approach = appleApproachRoute { allPoints += approach }
        else if let fallback = fallbackRoute { allPoints += fallback }
        
        if let ascent = offlineAscentRoute, !ascent.isEmpty {
            let safeIntercept = min(max(0, interceptIndex), ascent.count - 1)
            allPoints += Array(ascent[safeIntercept...])
        }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            if !allPoints.isEmpty {
                let rects = allPoints.map { MKMapRect(origin: MKMapPoint($0), size: MKMapSize(width: 1, height: 1)) }
                var finalRect = rects.first!
                for rect in rects { finalRect = finalRect.union(rect) }
                cameraPosition = .rect(padMapRect(finalRect))
            } else if let target = targetMountain, let userLoc = gpsManager.currentLocation, let lat = target.latitude, let lon = target.longitude {
                let p1 = MKMapPoint(userLoc.coordinate)
                let p2 = MKMapPoint(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                let rect = MKMapRect(
                    x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                    width: abs(p1.x - p2.x), height: abs(p1.y - p2.y)
                )
                cameraPosition = .rect(padMapRect(rect))
            }
        }
    }

    // Apple Maps Routen-Berechnung — async, off main thread
    private func calculateRouteToMountain(from userLoc: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) {

        let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        
        // 1. Check if we have a predefined MountainRoute in the database
        if let target = targetMountain, let routes = target.routes, let firstRoute = routes.first {
            let decodedAscent = PolylineUtility.decode(polyline: firstRoute.route_polyline)
            
            guard !decodedAscent.isEmpty else {
                print("⚠️ Route Polyline konnte nicht dekodiert werden oder ist leer.")
                return
            }
            
            // 🟢 ZERSCHNEIDEN: Finde den Interception Point! Wo steigt der User am nächsten ein?
            var minDistance: CLLocationDistance = .infinity
            var bestIndex = 0
            for (i, coord) in decodedAscent.enumerated() {
                let dist = userCLLoc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
                if dist < minDistance {
                    minDistance = dist
                    bestIndex = i
                }
            }
            
            let interceptCoord = decodedAscent[bestIndex]
            let interceptCLLoc = CLLocation(latitude: interceptCoord.latitude, longitude: interceptCoord.longitude)
            
            withAnimation {
                self.offlineAscentRoute = decodedAscent
                self.interceptIndex = bestIndex
                self.fallbackRoute = [userLoc, interceptCoord]
                self.appleApproachRoute = nil
                self.updateClosestRouteIndex(to: userLoc)
            }
            
            // Lade echte Gehwege oder Straßen bis zum Intercept-Point (ohne Distanz-Limit!)
            // Trigger Pioneer Approach (Luftlinie) nur, wenn der User > 50km vom Einstiegspunkt weg ist
            if userCLLoc.distance(from: interceptCLLoc) > 50000 {
                return
            }
            
            Task {
                let request = MKDirections.Request()
                request.source = MKMapItem(location: userCLLoc, address: nil)
                request.destination = MKMapItem(location: interceptCLLoc, address: nil)
                request.transportType = .walking
                
                var calculatedRoute: MKRoute? = nil

                do {
                    let directions = MKDirections(request: request)
                    let response = try await directions.calculate()
                    calculatedRoute = response.routes.first
                } catch {
                    print("⚠️ Walking approach route calculation failed: \(error), trying automobile...")
                    do {
                        request.transportType = .automobile
                        let carDirections = MKDirections(request: request)
                        let carResponse = try await carDirections.calculate()
                        calculatedRoute = carResponse.routes.first
                    } catch {
                        print("⚠️ Automobile approach failed as well: \(error)")
                    }
                }
                
                if let route = calculatedRoute {
                    // MKPolyline wandeln in [CLLocationCoordinate2D]
                    let pointCount = route.polyline.pointCount
                    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
                    route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                    
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.appleApproachRoute = coords
                        self.fallbackRoute = nil
                        
                        if !self.isRunning {
                            let safeBestIndex = min(bestIndex, decodedAscent.count - 1)
                            let allActiveCoords = coords + Array(decodedAscent[safeBestIndex...])
                            if !allActiveCoords.isEmpty {
                                let rects = allActiveCoords.map { MKMapRect(origin: MKMapPoint($0), size: MKMapSize(width: 1, height: 1)) }
                                if var finalRect = rects.first {
                                    for r in rects { finalRect = finalRect.union(r) }
                                    self.cameraPosition = .rect(self.padMapRect(finalRect))
                                }
                            }
                        }
                    }
                }
            }
            return
        }

        // --- OLD LOGIC ---
        // 1. Sofortige weiße Luftlinie zeichnen, als Fallback
        withAnimation(.easeInOut(duration: 0.5)) {
            self.fallbackRoute = [userLoc, dest]
            if !self.isRunning {
                let p1 = MKMapPoint(userLoc)
                let p2 = MKMapPoint(dest)
                let rect = MKMapRect(
                    x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                    width: abs(p1.x - p2.x), height: abs(p1.y - p2.y)
                )
                self.cameraPosition = .rect(padMapRect(rect))
            }
        }

        // 2. Apple Maps nach offiziellem Wanderweg fragen (async, blockiert Main Thread nicht)
        Task {
            let request = MKDirections.Request()
            request.source = MKMapItem(location: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: dest.latitude, longitude: dest.longitude), address: nil)
            request.transportType = .walking

            let directions = MKDirections(request: request)
            do {
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    let pointCount = route.polyline.pointCount
                    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
                    route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                    
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.appleApproachRoute = coords
                        self.fallbackRoute = nil
                        if !self.isRunning {
                            self.cameraPosition = .rect(self.padMapRect(route.polyline.boundingMapRect))
                        }
                    }
                }
            } catch {
                print("⚠️ Apple Maps hat keinen Wanderweg gefunden: \(error.localizedDescription)")
            }
        }
    }
    
    private func padMapRect(_ rect: MKMapRect) -> MKMapRect {
        return MKMapRect(
            x: rect.origin.x - rect.size.width * 0.3,
            y: rect.origin.y - rect.size.height * 0.3,
            width: rect.size.width * 1.6,
            height: rect.size.height * 1.6
        )
    }

    // MARK: - Top Bar
    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                }

                Spacer()

                HStack(spacing: 6) {
                    if isRunning {
                        Circle().fill(statusDotColor)
                            .frame(width: 7, height: 7)
                            .opacity(blinkToggle ? 1 : 0.2)
                            .animation(.easeInOut(duration: 0.6), value: blinkToggle)
                    }
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.primary).tracking(2)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.04), lineWidth: 1))

                Spacer()

                VStack(spacing: 0) {
                    Text("+\(liveXP)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(gold)
                    Text("XP")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundColor(gold.opacity(0.6))
                }
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.12)).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(colors: [gold.opacity(0.6), gold],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * elevationProgress), height: 5)
                            .animation(.spring(response: 1.0, dampingFraction: 0.7), value: elevationProgress)
                    }
                }
                .frame(height: 5)

                HStack {
                    if let mt = targetMountain {
                        Text(mt.name.uppercased())
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.primary.opacity(0.4)).tracking(1.5)
                    } else {
                        Text("ELEVATION XP")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.primary.opacity(0.4)).tracking(1.5)
                    }
                    Spacer()
                    Text("\(Int(gpsManager.elevationGain))m")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(gold.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
    }

    // MARK: - Data Panel
    private var dataPanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            VStack(spacing: 20) {
                if panelCollapsed {
                    HStack(spacing: 16) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(Int(gpsManager.elevationGain))")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(gold)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: Int(gpsManager.elevationGain))
                            Text("Hm")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(gold.opacity(0.6))
                        }

                        Spacer()

                        Text(timeString(from: timeElapsed))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)

                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", gpsManager.distance / 1000))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("km")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary.opacity(0.5))
                        }
                    }

                    if timeElapsed == 0 && !isRunning {
                        Button(action: startRecording) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                Text("START MISSION")
                                    .font(.system(size: 14, weight: .black, design: .rounded)).tracking(2)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(gold)
                            .cornerRadius(28)
                            .shadow(color: gold.opacity(0.4), radius: 16, y: 6)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Button(action: togglePause) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            SlideToFinishControl(onComplete: endMission)
                                .id(sliderResetToken)
                        }
                    }
                } else {
                    VStack(spacing: 2) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(Int(gpsManager.elevationGain))")
                                .font(.system(size: 86, weight: .black, design: .rounded))
                                .foregroundColor(gold)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: Int(gpsManager.elevationGain))
                            Text("Hm")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(gold.opacity(0.6))
                                .padding(.bottom, 10)
                        }
                        Text("ELEVATION GAIN")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(.primary.opacity(0.35)).tracking(3)
                    }

                    Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1).padding(.horizontal, 10)

                    HStack(spacing: 0) {
                        VStack(spacing: 5) {
                            Text(timeString(from: timeElapsed))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                            Text("DURATION")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundColor(.primary.opacity(0.35)).tracking(2)
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle().fill(Color.gray.opacity(0.1)).frame(width: 1, height: 44)

                        VStack(spacing: 5) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(String(format: "%.2f", gpsManager.distance / 1000))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("km")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary.opacity(0.5))
                            }
                            Text("DISTANCE")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundColor(.primary.opacity(0.35)).tracking(2)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if gpsManager.rawRoute.count >= 2 && showElevationProfile {
                        ElevationProfileChart(locations: gpsManager.rawRoute)
                            .frame(height: 60)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if timeElapsed == 0 && !isRunning {
                        Button(action: startRecording) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                Text("START MISSION")
                                    .font(.system(size: 14, weight: .black, design: .rounded)).tracking(2)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(gold)
                            .cornerRadius(28)
                            .shadow(color: gold.opacity(0.4), radius: 16, y: 6)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Button(action: togglePause) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(width: 56, height: 56)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                            }

                            if gpsManager.rawRoute.count >= 2 {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showElevationProfile.toggle()
                                    }
                                }) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(showElevationProfile ? gold : .primary)
                                        .frame(width: 56, height: 56)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                                }
                            }

                            SlideToFinishControl(onComplete: endMission)
                                .id(sliderResetToken)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 38)
        }
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 30, y: -10)
        )
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if value.translation.height > 40 {
                            panelCollapsed = true
                        } else if value.translation.height < -40 {
                            panelCollapsed = false
                        }
                    }
                }
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 30)
    }

    private func startRecording() {
        HapticManager.shared.medium()
        isRunning = true
        
        gpsManager.logManualResume()
        gpsManager.startTracking()
        
        // 🟢 Wir springen NICHT mehr hart auf den User,
        // stattdessen lassen wir die Kamera einfach dort, wo sie ist (oft bei der Route).
        // Wenn der User sich selbst zentrieren will, kann er den "Location"-Button rechts drücken.
    }

    private func togglePause() {
        HapticManager.shared.medium()
        isRunning.toggle()
        if isRunning {
            gpsManager.logManualResume()
            gpsManager.startTracking()
        } else {
            gpsManager.stopTracking()
            gpsManager.logManualPause()
        }
    }

    func timeString(from seconds: Int) -> String {
        let h = seconds / 3600; let m = (seconds % 3600) / 60; let s = seconds % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    func endMission() {
        isRunning = false
        gpsManager.stopTracking()
        gpsManager.finalizeSession()
        showSaveForm = true
    }
}

// =========================================
// === Slide-to-Finish Safety Control ===
// =========================================
struct SlideToFinishControl: View {
    var onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted = false

    private let thumbSize: CGFloat = 48
    private let trackHeight: CGFloat = 56
    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)

    var body: some View {
        GeometryReader { geo in
            let maxDrag = geo.size.width - thumbSize - 8

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.red.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.red.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(
                        Text("SLIDE TO FINISH")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(.primary.opacity(max(0.35 - (dragOffset / maxDrag) * 0.35, 0)))
                            .tracking(2)
                    )

                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.red.opacity(0.15))
                    .frame(width: dragOffset + thumbSize + 8)

                ZStack {
                    Circle()
                        .fill(Color(red: 0.25, green: 0.06, blue: 0.06))
                        .frame(width: thumbSize, height: thumbSize)
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                        .frame(width: thumbSize, height: thumbSize)
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
                .offset(x: 4 + dragOffset)
                .shadow(color: Color.red.opacity(0.3), radius: 10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isCompleted else { return }
                            dragOffset = min(max(0, value.translation.width), maxDrag)
                        }
                        .onEnded { _ in
                            guard !isCompleted else { return }
                            if dragOffset > maxDrag * 0.8 {
                                isCompleted = true
                                HapticManager.shared.heavy()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = maxDrag
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onComplete()
                                }
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .frame(height: trackHeight)
    }
}

// =========================================
// === HILFS-VIEW: Das smarte Save-Formular ===
// =========================================
struct MissionSaveView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var targetMountain: Mountain?
    var elevationMeters: Int
    var durationSeconds: TimeInterval
    var distanceKm: Double
    var pauseLog: [PauseEntry]
    var totalPauseDuration: TimeInterval
    var onDismissTracker: () -> Void

    @State private var summitName: String = ""
    @State private var storyComment: String = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var isVerifiedSummit: Bool {
        guard let mountain = targetMountain else { return false }
        return elevationMeters >= Int(Double(mountain.elevation) * 0.8)
    }

    var xpGained: Int {
        let baseXP = 100 + elevationMeters
        return isVerifiedSummit ? baseXP + 500 : baseXP
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .abbreviated
        return f
    }()

    var formattedDuration: String {
        Self.durationFormatter.string(from: durationSeconds) ?? "0m"
    }

    var body: some View {
        NavigationView {
            Form {
                if let mountain = targetMountain {
                    Section {
                        HStack {
                            if isVerifiedSummit {
                                Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.system(.title, design: .rounded))
                                VStack(alignment: .leading) {
                                    Text("Verified Summit").font(.system(.headline, design: .rounded)).foregroundColor(.green)
                                    Text("You conquered \(mountain.name)! (+500 Bonus XP)").font(.system(.caption, design: .rounded)).foregroundColor(.gray)
                                }
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.system(.title, design: .rounded))
                                VStack(alignment: .leading) {
                                    Text("Mission Attempt").font(.system(.headline, design: .rounded)).foregroundColor(.orange)
                                    Text("Elevation too low to verify summit.").font(.system(.caption, design: .rounded)).foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }

                Section(header: Text("Summit Info")) {
                    TextField("Summit Name (e.g., Zugspitze)", text: $summitName)
                }

                Section(header: Text("Your Story")) {
                    TextEditor(text: $storyComment)
                        .frame(height: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }

                Section(header: Text("Tour Photo")) {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(height: 180).clipped().cornerRadius(12)
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(photoData == nil ? "Add Photo" : "Change Photo")
                        }
                    }
                    .onChange(of: photoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                self.photoData = data
                            }
                        }
                    }
                }

                Section(header: Text("Live Tracker Stats")) {
                    HStack { Text("Elevation:"); Spacer(); Text("\(elevationMeters) m").foregroundColor(.gray) }
                    HStack { Text("Duration:"); Spacer(); Text(formattedDuration).foregroundColor(.gray) }
                    HStack { Text("Distance:"); Spacer(); Text(String(format: "%.1f km", distanceKm)).foregroundColor(.gray) }
                    HStack { Text("XP Gained:"); Spacer(); Text("+\(xpGained) XP").foregroundColor(.blue).fontWeight(.bold) }
                }

                if !pauseLog.isEmpty {
                    Section(header: Text("Pauses")) {
                        ForEach(pauseLog) { pause in
                            HStack {
                                Image(systemName: pause.isAutomatic ? "pause.circle" : "hand.raised")
                                    .font(.system(.caption, design: .rounded)).foregroundColor(.orange)
                                Text(pause.isAutomatic ? "Auto" : "Manual")
                                    .font(.system(.subheadline, design: .rounded))
                                Spacer()
                                Text(formatPauseDuration(pause.duration))
                                    .font(.system(.subheadline, design: .rounded)).foregroundColor(.gray)
                            }
                        }
                        HStack {
                            Text("Total Pause Time").fontWeight(.medium)
                            Spacer()
                            Text(formatPauseDuration(totalPauseDuration))
                                .foregroundColor(.orange).fontWeight(.bold)
                        }
                    }
                }
            }
            .navigationTitle("Save Your Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        appState.addCompletedTour(
                            summit: summitName,
                            comment: storyComment,
                            elevation: elevationMeters,
                            duration: durationSeconds,
                            distance: distanceKm,
                            xp: xpGained,
                            pauses: pauseLog,
                            photoData: photoData
                        )
                        dismiss()
                        onDismissTracker()
                    }
                    .fontWeight(.bold)
                    .disabled(summitName.isEmpty || storyComment.isEmpty)
                }
            }
            .onAppear {
                if let prefilledName = targetMountain?.name {
                    summitName = prefilledName
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func formatPauseDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// =========================================
// === ELEVATION PROFILE CHART ===
// =========================================

struct ElevationProfileChart: View {
    let locations: [CLLocation]

    private var chartData: [(id: Int, distanceKm: Double, altitudeM: Double)] {
        guard locations.count >= 2 else { return [] }
        var result: [(id: Int, distanceKm: Double, altitudeM: Double)] = []
        var cumDistance: Double = 0
        result.append((id: 0, distanceKm: 0, altitudeM: locations[0].altitude))
        for i in 1..<locations.count {
            cumDistance += locations[i].distance(from: locations[i - 1])
            result.append((id: i, distanceKm: cumDistance / 1000.0, altitudeM: locations[i].altitude))
        }
        return result
    }

    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)

    var body: some View {
        Chart {
            ForEach(chartData, id: \.id) { point in
                AreaMark(
                    x: .value("Distance", point.distanceKm),
                    y: .value("Altitude", point.altitudeM)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [gold.opacity(0.3), gold.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Distance", point.distanceKm),
                    y: .value("Altitude", point.altitudeM)
                )
                .foregroundStyle(gold)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel().foregroundStyle(.gray).font(.system(size: 9, design: .rounded))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel().foregroundStyle(.gray).font(.system(size: 9, design: .rounded))
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }
}
