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
        // Cap both arrays to prevent unbounded memory growth on long hikes
        if rawRoute.count > Self.maxRawRoutePoints {
            rawRoute.removeFirst(rawRoute.count - Self.maxRawRoutePoints)
        }
        if routePoints.count > Self.maxRawRoutePoints {
            routePoints.removeFirst(routePoints.count - Self.maxRawRoutePoints)
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
    @StateObject private var navigationManager = NavigationManager()
    @ObservedObject private var weatherManager = WeatherManager.shared
    @StateObject private var photoHighlightManager = PhotoHighlightManager()
    @ObservedObject private var emergencyManager = EmergencyManager.shared

    @State private var timeElapsed: Int = 0
    @State private var isRunning: Bool = false
    @State private var blinkToggle: Bool = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var cameraPosition: MapCameraPosition

    @State private var showSaveForm = false
    @State private var showElevationProfile = false
    @State private var showExportSheet = false
    @State private var showWeatherDetail = false
    @State private var showTrackerSettings = false
    @State private var panelCollapsed = false
    @State private var navHUDCollapsed = false
    @State private var sliderResetToken = UUID()
    
    // 🟢 Speichert die berechneten Routen
    @State private var appleApproachRoute: [CLLocationCoordinate2D]? = nil
    @State private var offlineAscentRoute: [CLLocationCoordinate2D]? = nil
    
    @State private var interceptIndex: Int = 0
    @State private var closestRouteIndex: Int? = nil

    @State private var hasCalculatedRoute = false
    @State private var isTooFarForRoute = false
    @State private var isMapCenteredOnUser = true

    private let gold = DesignSystem.Colors.accent
    @AppStorage("routeColor") private var routeColorName: String = "blue"
    @AppStorage("turnByTurnEnabled") private var turnByTurnEnabled = false

    private var userRouteColor: Color {
        switch routeColorName {
        case "red":    return .red
        case "green":  return .green
        case "orange": return .orange
        default:       return DesignSystem.Colors.accent
        }
    }

    init(targetMountain: Mountain?) {
        self.targetMountain = targetMountain
        
        if let target = targetMountain, let lat = target.latitude, let lon = target.longitude {
            // Center on mountain initially, recenter button will appear
            _cameraPosition = State(initialValue: .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distance: 15000)))
            _isMapCenteredOnUser = State(initialValue: false)
        } else {
            // Center on user location
            _cameraPosition = State(initialValue: .userLocation(fallback: .automatic))
        }
    }

    private var elevationProgress: Double {
        guard gpsManager.elevationGain > 0 else { return 0 }
        if let target = targetMountain {
            return min(gpsManager.elevationGain / Double(target.elevation), 1.0)
        }
        return gpsManager.elevationGain.truncatingRemainder(dividingBy: 500.0) / 500.0
    }

    private var liveXP: Int {
        if let target = targetMountain {
            // XP = base 50 + 1 XP per meter of elevation gained, capped at mountain height
            let gained = min(gpsManager.elevationGain, Double(target.elevation))
            return 50 + Int(gained)
        }
        return 50 + Int(gpsManager.elevationGain)
    }
    
    private var mountainXPPotential: Int {
        if let target = targetMountain {
            return 50 + target.elevation
        }
        return 0
    }

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
                
                if let approach = appleApproachRoute {
                    MapPolyline(coordinates: approach)
                        .stroke(.gray.opacity(0.82), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                
                // 🟢 Zeichnet die Offline Ascent Polyline (z.T. ignoriert, z.T. aktiv)
                if let routeCoords = offlineAscentRoute, routeCoords.count > 1 {
                    
                    let safeIntercept = min(max(0, interceptIndex), routeCoords.count - 1)
                    let safeActiveStart = min(max(safeIntercept, closestRouteIndex ?? safeIntercept), routeCoords.count - 1)
                    
                    // Der ignorierte untere Teil (vor dem Interception Point)
                    if safeIntercept > 0 {
                        MapPolyline(coordinates: Array(routeCoords[0...safeIntercept]))
                            .stroke(.gray.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                    
                    // Das Stück vom Interception-Point bis zur aktuellen User-Position (bereits gelaufen / grau)
                    if safeActiveStart > safeIntercept {
                        MapPolyline(coordinates: Array(routeCoords[safeIntercept...safeActiveStart]))
                            .stroke(.gray.opacity(0.68), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
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
                        .stroke(userRouteColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls { }
            .safeAreaPadding(.bottom, -40)
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .onEnd) { context in
                if let userLoc = gpsManager.currentLocation {
                    let camCenter = context.region.center
                    let camLoc = CLLocation(latitude: camCenter.latitude, longitude: camCenter.longitude)
                    let distance = userLoc.distance(from: camLoc)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isMapCenteredOnUser = distance < 500
                    }
                }
            }
            .onChange(of: gpsManager.currentLocation) { _, newLoc in
                guard let loc = newLoc else { return }

                // Feed navigation manager with GPS updates
                if navigationManager.isNavigating {
                    navigationManager.updateLocation(loc)
                }

                // Update live tracking position
                if emergencyManager.isLiveTracking {
                    Task { await emergencyManager.updateLiveLocation(loc) }
                }

                // Off-Route Detection: Snapping & Splitting update
                updateClosestRouteIndex(to: loc.coordinate)
                
                print("🧭 GPS: onChange fired — target=\(targetMountain?.name ?? "nil"), hasCalc=\(hasCalculatedRoute), lat=\(targetMountain?.latitude ?? -1)")
                
                guard let target = targetMountain, !hasCalculatedRoute,
                      let targetLat = target.latitude, let targetLon = target.longitude else { return }
                
                hasCalculatedRoute = true
                withAnimation { self.isTooFarForRoute = false }
                calculateRouteToMountain(from: loc.coordinate, to: CLLocationCoordinate2D(latitude: targetLat, longitude: targetLon))
            }

            // === LAYER 2: Lightening overlay ===
            Color.white.opacity(0.4).ignoresSafeArea()
                .allowsHitTesting(false)

            // === LAYER 3: Top gradient ===
            VStack {
                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.5), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200).ignoresSafeArea()
                    .allowsHitTesting(false)
                Spacer()
            }

            // === LAYER 4: Bottom gradient ===
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .white.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 300).ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // === LAYER 5: Map Controls (Buttons) ===
            VStack(spacing: 10) {
                if targetMountain != nil {
                    Button(action: viewFullRoute) {
                        Image(systemName: "map")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    }
                }

                if !isMapCenteredOnUser {
                    Button(action: centerOnUser) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(gold)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Weather button
                if weatherManager.currentWeather != nil {
                    Button(action: { showWeatherDetail.toggle() }) {
                        VStack(spacing: 2) {
                            Image(systemName: weatherManager.currentWeather?.conditionSymbol ?? "cloud")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 15))
                            Text(weatherManager.currentWeather?.temperatureFormatted ?? "")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                        }
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    }
                }

                // Photo capture
                if isRunning {
                    PhotoCaptureButton(
                        currentLocation: gpsManager.currentLocation,
                        photoManager: photoHighlightManager
                    )
                }

                // SOS Button
                if isRunning {
                    SOSButtonView(
                        emergencyManager: emergencyManager,
                        currentLocation: gpsManager.currentLocation
                    )
                }

                // Restart Navigation button (visible when nav was stopped but route exists)
                if isRunning && !navigationManager.isNavigating && turnByTurnEnabled &&
                   (offlineAscentRoute != nil || appleApproachRoute != nil) {
                    Button(action: {
                        HapticManager.shared.light()
                        startNavigationIfReady()
                    }) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.cyan)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.trailing, 16)
            .padding(.top, navigationManager.isNavigating ? (navHUDCollapsed ? 200 : 280) : 140)

            // Navigation HUD overlay
            if navigationManager.isNavigating {
                VStack {
                    Spacer().frame(height: navHUDCollapsed ? 140 : 180)
                    HStack { NavigationHUDView(navManager: navigationManager, isCollapsed: $navHUDCollapsed); if navHUDCollapsed { Spacer() } }
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .allowsHitTesting(true)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: navHUDCollapsed)
            }

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
            if isRunning && !gpsManager.isAutoPaused { 
                timeElapsed += 1 
                appState.trackerElapsedSeconds = timeElapsed
            }
            appState.trackerDistanceKm = gpsManager.distance / 1000.0
            appState.trackerElevationGain = gpsManager.elevationGain
            appState.isTrackerPaused = !isRunning || gpsManager.isAutoPaused
            
            #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                let isPaused = !isRunning || gpsManager.isAutoPaused
                let speedMps = timeElapsed > 0 ? (Double(gpsManager.distance) / Double(timeElapsed)) : 0
                LiveActivityManager.shared.updateActivity(
                    duration: Double(timeElapsed),
                    distanceMeter: gpsManager.distance,
                    remainingDistanceMeter: navigationManager.totalRemainingDistance,
                    speedMetersPerSecond: speedMps,
                    isPaused: isPaused
                )
            }
            #endif

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
                rawRoute: gpsManager.rawRoute,
                photoHighlights: photoHighlightManager.highlights,
                onDismissTracker: { dismiss() }
            )
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheetView(
                tourName: targetMountain?.name ?? "Tour",
                tourDate: Date(),
                routePoints: gpsManager.rawRoute
            )
        }
        .sheet(isPresented: $showWeatherDetail) {
            if let weather = weatherManager.currentWeather {
                NavigationView {
                    ScrollView {
                        WeatherCardView(weather: weather, compact: false)
                            .padding(20)
                    }
                    .navigationTitle("Weather Conditions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showWeatherDetail = false }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showTrackerSettings) {
            TrackerSettingsSheet()
        }
        .onChange(of: offlineAscentRoute?.count) { _, _ in
            if isRunning, turnByTurnEnabled, !navigationManager.isNavigating {
                startNavigationIfReady()
            }
        }
        .onChange(of: appleApproachRoute?.count) { _, _ in
            if isRunning, turnByTurnEnabled, !navigationManager.isNavigating {
                startNavigationIfReady()
            }
        }
    }

    // 🟢 Navigation starten sobald irgendeine Route verfügbar ist
    private func startNavigationIfReady() {
        print("🧭 NAV: startNavigationIfReady called — isNavigating=\(navigationManager.isNavigating)")
        guard !navigationManager.isNavigating else { return }
        
        print("🧭 NAV: offlineRoute=\(offlineAscentRoute?.count ?? 0), appleRoute=\(appleApproachRoute?.count ?? 0)")
        
        // Priority 1: Offline ascent route (from database)
        if let route = offlineAscentRoute, !route.isEmpty {
            let startIndex = min(max(0, interceptIndex), route.count - 1)
            let navCoords = Array(route[startIndex...])
            print("🧭 NAV: ✅ Starting with offline route (\(navCoords.count) points)")
            navigationManager.startNavigation(coordinates: navCoords, mountainName: targetMountain?.name)
            return
        }
        
        // Priority 2: Apple Maps approach route
        if let route = appleApproachRoute, !route.isEmpty {
            print("🧭 NAV: ✅ Starting with Apple route (\(route.count) points)")
            navigationManager.startNavigation(coordinates: route, mountainName: targetMountain?.name)
            return
        }
        
        print("🧭 NAV: ❌ No route available yet")
    }

    // 🟢 BUTTON-FUNKTION: Zurück auf User zoomen
    private func centerOnUser() {
        HapticManager.shared.light()
        if let userLoc = gpsManager.currentLocation {
            withAnimation(.easeInOut(duration: 1.0)) {
                cameraPosition = .camera(MapCamera(centerCoordinate: userLoc.coordinate, distance: 3000))
                isMapCenteredOnUser = true
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
        else if let ascent = offlineAscentRoute, !ascent.isEmpty {
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

    // 🟢 GEFIXT: Apple Maps Routen-Berechnung (Entfernt 50km Sperre & nutzt Auto-Routing!)
    private func calculateRouteToMountain(from userLoc: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) {
        let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        
        print("🧭 ROUTE: calculateRouteToMountain called")
        print("🧭 ROUTE: target.routes = \(targetMountain?.routes?.count ?? -1)")
        
        // 1. Check if we have a predefined MountainRoute in the database
        if let target = targetMountain, let routes = target.routes, let firstRoute = routes.first {
            let decodedAscent = PolylineUtility.decode(polyline: firstRoute.route_polyline)
            
            print("🧭 ROUTE: Decoded ascent route with \(decodedAscent.count) points")
            guard !decodedAscent.isEmpty else { return }
            
            // Finde den Interception Point! Wo steigt der User am nächsten ein?
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
                self.appleApproachRoute = nil
                self.updateClosestRouteIndex(to: userLoc)
            }
            
            // Abbrechen nur bei interkontinentalen Distanzen (z.B. > 2.000 km)
            if userCLLoc.distance(from: interceptCLLoc) > 2_000_000 {
                return
            }
            
            Task {
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: interceptCoord))
                
                // WICHTIG: Zuerst Auto probieren! Apple weigert sich oft, weite Strecken als "Walking" zu berechnen.
                request.transportType = .automobile
                
                var calculatedRoute: MKRoute? = nil

                do {
                    let directions = MKDirections(request: request)
                    let response = try await directions.calculate()
                    calculatedRoute = response.routes.first
                } catch {
                    print("⚠️ Auto-Anreise fehlgeschlagen, versuche Fußweg: \(error.localizedDescription)")
                    do {
                        request.transportType = .walking
                        let directions = MKDirections(request: request)
                        let response = try await directions.calculate()
                        calculatedRoute = response.routes.first
                    } catch {
                        print("⚠️ Fußweg ebenfalls fehlgeschlagen: \(error.localizedDescription)")
                    }
                }
                
                if let route = calculatedRoute {
                    let pointCount = route.polyline.pointCount
                    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
                    route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                    
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            self.appleApproachRoute = coords
                            
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
                        // Trigger navigation if recording is already active
                        if self.isRunning && self.turnByTurnEnabled {
                            self.startNavigationIfReady()
                        }
                    }
                }
            }
            return
        }

        // --- OLD LOGIC (Falls Berg noch keine offizielle Route in der Datenbank hat) ---
        withAnimation(.easeInOut(duration: 0.5)) {
            self.appleApproachRoute = [userLoc, dest]
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

        Task {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
            request.transportType = .automobile // Auch hier .automobile als Standard setzen

            var calculatedRoute: MKRoute? = nil
            
            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                calculatedRoute = response.routes.first
            } catch {
                do {
                    request.transportType = .walking
                    let directions = MKDirections(request: request)
                    let response = try await directions.calculate()
                    calculatedRoute = response.routes.first
                } catch { }
            }
            
            if let route = calculatedRoute {
                let pointCount = route.polyline.pointCount
                var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
                route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.appleApproachRoute = coords
                        if !self.isRunning {
                            self.cameraPosition = .rect(self.padMapRect(route.polyline.boundingMapRect))
                        }
                    }
                    // Trigger navigation if recording is already active
                    if self.isRunning && self.turnByTurnEnabled {
                        self.startNavigationIfReady()
                    }
                }
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
                Button(action: {
                    if isRunning || timeElapsed > 0 || appState.isTrackerPaused {
                        withAnimation { appState.isTrackerMinimized = true }
                    } else {
                        withAnimation { appState.isTrackerActive = false }
                    }
                }) {
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
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(gold)
                    if mountainXPPotential > 0 {
                        Text("/\(mountainXPPotential)")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundColor(gold.opacity(0.4))
                    } else {
                        Text("XP")
                            .font(.system(size: 7, weight: .black, design: .rounded))
                            .foregroundColor(gold.opacity(0.6))
                    }
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
                    if let mt = targetMountain {
                        Text("\(Int(gpsManager.elevationGain))m / \(mt.elevation)m")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(gold.opacity(0.9))
                    } else {
                        Text("\(Int(gpsManager.elevationGain))m")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(gold.opacity(0.9))
                    }
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
                HStack {
                    Spacer()
                    Button(action: { showTrackerSettings = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.88))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                    }
                }
                .padding(.bottom, 2)

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
                            
                            if !isRunning {
                                Button(action: {
                                    HapticManager.shared.heavy()
                                    withAnimation { appState.isTrackerActive = false }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                        .frame(width: 56, height: 56)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                                }
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

                            if !isRunning {
                                Button(action: {
                                    HapticManager.shared.heavy()
                                    withAnimation { appState.isTrackerActive = false }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(.red.opacity(0.85), in: Circle())
                                        .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
                                }
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
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.startActivity(mountainName: targetMountain?.name ?? "Mission")
        }
        #endif

        HapticManager.shared.medium()
        isRunning = true
        
        // Collapse panel when recording starts for more map visibility
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            panelCollapsed = true
        }

        gpsManager.logManualResume()
        gpsManager.startTracking()

        // Force route calculation if it hasn't happened yet (e.g. simulator with static location)
        if !hasCalculatedRoute, let target = targetMountain,
           let targetLat = target.latitude, let targetLon = target.longitude {
            hasCalculatedRoute = true
            
            // Use current location or fallback to target coords
            let userCoord: CLLocationCoordinate2D
            if let loc = gpsManager.currentLocation {
                userCoord = loc.coordinate
            } else {
                // On simulator, CLLocationManager may have a cached location
                let locManager = CLLocationManager()
                if let loc = locManager.location {
                    userCoord = loc.coordinate
                } else {
                    userCoord = CLLocationCoordinate2D(latitude: targetLat, longitude: targetLon)
                }
            }
            
            print("🧭 NAV: Force calculating route from \(userCoord.latitude),\(userCoord.longitude)")
            calculateRouteToMountain(from: userCoord, to: CLLocationCoordinate2D(latitude: targetLat, longitude: targetLon))
        }

        // Start navigation if we have a route AND user has enabled turn-by-turn
        print("🧭 NAV: startRecording — turnByTurnEnabled=\(turnByTurnEnabled)")
        if turnByTurnEnabled {
            startNavigationIfReady()
            
            // Retry after 3 seconds in case route was being calculated async
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.isRunning && self.turnByTurnEnabled && !self.navigationManager.isNavigating {
                    print("🧭 NAV: Retry after 3s — offlineRoute=\(self.offlineAscentRoute?.count ?? 0), appleRoute=\(self.appleApproachRoute?.count ?? 0)")
                    self.startNavigationIfReady()
                }
            }
        }

        // Fetch weather for current/target location
        if let target = targetMountain, let lat = target.latitude, let lon = target.longitude {
            Task { await weatherManager.fetchWeather(latitude: lat, longitude: lon) }
        } else if let loc = gpsManager.currentLocation {
            Task { await weatherManager.fetchWeather(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude) }
        }

        // Start live tracking if enabled
        if UserDefaults.standard.bool(forKey: "liveTrackingDefault") {
            Task { await emergencyManager.startLiveTracking(tourName: targetMountain?.name) }
        }
    }

    private func shareLocation() {
        guard let loc = gpsManager.currentLocation else { return }
        let text = emergencyManager.shareCurrentLocation(loc)
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
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
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.endActivity()
        }
        #endif

        isRunning = false
        gpsManager.stopTracking()
        gpsManager.finalizeSession()
        navigationManager.stopNavigation()
        Task { await emergencyManager.stopLiveTracking() }
        showSaveForm = true
    }
}

// =========================================
// === Tracker Settings Sheet ===
// =========================================
struct TrackerSettingsSheet: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage("turnByTurnEnabled") private var turnByTurnEnabled = false
    @AppStorage("voiceGuidanceEnabled") private var voiceGuidanceEnabled = true
    @AppStorage("routeColor") private var routeColorName: String = "blue"

    private let accentBlue = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Navigation
                        SettingsSection(title: "NAVIGATION") {
                            Toggle(isOn: $turnByTurnEnabled) {
                                SettingsRowLabel(icon: "arrow.triangle.turn.up.right.diamond.fill", iconColor: .cyan, text: "Turn-by-Turn Guidance")
                            }
                            .tint(accentBlue)

                            if turnByTurnEnabled {
                                Divider().background(Color.black.opacity(0.1))

                                Toggle(isOn: $voiceGuidanceEnabled) {
                                    SettingsRowLabel(icon: "speaker.wave.2.fill", iconColor: .purple, text: "Voice Announcements")
                                }
                                .tint(accentBlue)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: turnByTurnEnabled)

                        // MARK: - Route Appearance
                        SettingsSection(title: "ROUTE APPEARANCE") {
                            VStack(alignment: .leading, spacing: 12) {
                                SettingsRowLabel(icon: "paintbrush.fill", iconColor: .orange, text: "Route Color")

                                HStack(spacing: 14) {
                                    ForEach(RouteColorOption.allCases, id: \.rawValue) { option in
                                        Button(action: { routeColorName = option.rawValue }) {
                                            ZStack {
                                                Circle()
                                                    .fill(option.color)
                                                    .frame(width: 36, height: 36)
                                                    .shadow(color: option.color.opacity(0.4), radius: routeColorName == option.rawValue ? 6 : 0)

                                                if routeColorName == option.rawValue {
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 3)
                                                        .frame(width: 36, height: 36)
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 12, weight: .black))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.leading, 47) // align with label text
                            }
                        }

                        // MARK: - Info
                        VStack(spacing: 4) {
                            Text("Navigation settings apply to the current and future sessions.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.gray.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Tracker Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Color(white: 0.98), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(.title3, design: .rounded))
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.light)
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
    private let gold = DesignSystem.Colors.accent

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
    var rawRoute: [CLLocation]
    var photoHighlights: [PhotoHighlight]
    var onDismissTracker: () -> Void

    @State private var summitName: String = ""
    @State private var storyComment: String = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var showExportSheet = false

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

                // Photo highlights from tour
                if !photoHighlights.isEmpty {
                    Section(header: Text("Photo Highlights (\(photoHighlights.count))")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoHighlights) { highlight in
                                    if let data = highlight.localImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable().scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                }

                // Export section
                if !rawRoute.isEmpty {
                    Section(header: Text("Export")) {
                        Button(action: { showExportSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(DesignSystem.Colors.accent)
                                Text("Export as GPX / KML")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
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
                            photoData: photoData,
                            rawRoute: rawRoute
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
            .sheet(isPresented: $showExportSheet) {
                ExportSheetView(
                    tourName: summitName.isEmpty ? "Tour" : summitName,
                    tourDate: Date(),
                    routePoints: rawRoute
                )
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

    private let gold = DesignSystem.Colors.accent

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
