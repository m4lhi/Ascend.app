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


class LiveGPSManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()

    @Published var distance: Double = 0.0
    @Published var elevationGain: Double = 0.0
    @Published var currentLocation: CLLocation?
    @Published var routePoints: [CLLocationCoordinate2D] = []
    private(set) var rawRoute: [CLLocation] = [] // Preserved raw GPS fixes — never overwritten
    private var lastLocation: CLLocation?

    // CMAltimeter state (Prompt 1 — unchanged)
    private let isAltimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    private var altimeterRelativeAltitude: Double? = nil
    private var altimeterBaseline: Double? = nil    // GPS altitude at session start
    private var altimeterStarted = false

    // Smoothing buffer (Prompt 1 — unchanged, window: 5 samples)
    private var altitudeBuffer: [Double] = []
    private let smoothingWindow = 5

    // Noise threshold state (Prompt 1 — unchanged, 5 m in 10 s window)
    private var windowStartTime: Date = Date()
    private var windowStartAltitude: Double? = nil
    private let noiseThresholdMeters: Double = 5.0
    private let noiseWindowSeconds: Double = 10.0

    // --- Auto-pause state ---
    @Published var isAutoPaused: Bool = false
    @Published var pauseLog: [PauseEntry] = []
    @Published var totalPauseDuration: TimeInterval = 0

    // Speed-based auto-pause detection
    private var lowSpeedStart: Date? = nil
    private let autoPauseSpeedThreshold: Double = 0.5  // km/h
    private let autoPauseDelay: TimeInterval = 8.0     // seconds

    // GPS drift detection buffer (last 10 points)
    private var recentLocations: [CLLocation] = []
    private let driftBufferSize = 10
    private let driftStddevThreshold: Double = 5.0     // meters

    // Active pause tracking (shared between auto and manual pauses)
    private var currentPauseStart: Date? = nil
    private var currentPauseCoordinate: CLLocationCoordinate2D? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        manager.startUpdatingLocation()
        lastLocation = nil // Don't accumulate distance from pre-pause point
        // Start altimeter once per session; pause/play must not reset the baseline.
        if isAltimeterAvailable && !altimeterStarted {
            altimeterStarted = true
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.altimeterRelativeAltitude = data.relativeAltitude.doubleValue
            }
        }
    }

    // Pauses GPS collection without disturbing the altimeter baseline.
    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    // Records the start of a manual pause.
    func logManualPause() {
        // If auto-paused when the user manually pauses, close the auto-pause first
        if isAutoPaused {
            closeCurrentPause(isAutomatic: true)
            isAutoPaused = false
        }
        currentPauseStart = Date()
        currentPauseCoordinate = currentLocation?.coordinate
    }

    // Records the end of a manual pause.
    func logManualResume() {
        closeCurrentPause(isAutomatic: false)
        lowSpeedStart = nil           // Fresh auto-pause detection after manual resume
        recentLocations.removeAll()   // Clear drift buffer so old points don't trigger false pause
    }

    // Called once when the session truly ends (before the save form is shown).
    // Stops the altimeter and applies post-hoc smoothing to produce the final elevation value.
    func finalizeSession() {
        // Close any ongoing pause (auto or manual)
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

    // --- Pause bookkeeping ---

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

    // --- Elevation helpers (Prompt 1 — unchanged) ---

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

    // Recalculates elevationGain using a 5-sample moving average over the preserved raw GPS trail.
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
        elevationGain = smoothedGain
    }

    // --- Auto-pause detection ---

    /// Stationary if GPS drift stddev < 5 m (regardless of speed) OR speed < 0.5 km/h.
    private func isStationary(speed speedKmh: Double) -> Bool {
        if recentLocations.count >= driftBufferSize {
            let stddev = locationStddev(recentLocations.suffix(driftBufferSize))
            if stddev < driftStddevThreshold { return true }
        }
        return speedKmh < autoPauseSpeedThreshold
    }

    /// Standard deviation of distances from the centroid of the given locations.
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
        lastLocation = nil // Don't accumulate drift-distance on resume
    }

    // --- Main GPS delegate ---

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        currentLocation = newLocation

        // Always update the drift-detection buffer (needed to detect exit from pause too)
        recentLocations.append(newLocation)
        if recentLocations.count > driftBufferSize { recentLocations.removeFirst() }

        // Auto-pause entry / exit
        let speedKmh = max(newLocation.speed * 3.6, 0)

        if isAutoPaused {
            // Exit auto-pause on speed only (more responsive than drift which has buffer lag)
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

        // Skip all metric accumulation while auto-paused
        guard !isAutoPaused else { return }

        routePoints.append(newLocation.coordinate)
        rawRoute.append(newLocation) // always preserve the raw GPS fix

        // Anchor the altimeter baseline to the first GPS fix of this session
        if altimeterBaseline == nil { altimeterBaseline = newLocation.altitude }

        let effAlt = effectiveAltitude(for: newLocation)
        let smoothAlt = smoothed(altitude: effAlt)

        // Noise threshold: only accumulate gain if ≥ 5 m within a 10 s window
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
// === Full-screen map, glassmorphism panel ===
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

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.421, longitude: 10.984),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )))

    @State private var showSaveForm = false
    @State private var showElevationProfile = false
    @State private var panelCollapsed = false
    @State private var sliderResetToken = UUID()

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    // Elevation progress — fills per 500m milestone
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
        ZStack {
            // === LAYER 1: Full-screen satellite map ===
            Map(position: $cameraPosition) {
                UserAnnotation()
                if !gpsManager.routePoints.isEmpty {
                    MapPolyline(coordinates: gpsManager.routePoints)
                        .stroke(gold, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea()

            // === LAYER 2: Darkening overlay ===
            Color.black.opacity(0.25).ignoresSafeArea()

            // === LAYER 3: Top gradient for legibility ===
            VStack {
                LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.3), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200).ignoresSafeArea()
                Spacer()
            }

            // === LAYER 4: Bottom gradient for panel ===
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 300).ignoresSafeArea()
            }

            // === LAYER 5: Content ===
            VStack(spacing: 0) {
                topBar
                Spacer()
                dataPanel
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            blinkToggle.toggle()
            if isRunning && !gpsManager.isAutoPaused { timeElapsed += 1 }
        }
        .sheet(isPresented: $showSaveForm, onDismiss: {
            // Reset slider so it's not stuck if user discards save
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

    // MARK: - Top Bar with XP Progress

    private var topBar: some View {
        VStack(spacing: 14) {
            // Row: Close — Status — XP
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Spacer()

                // Status pill
                HStack(spacing: 6) {
                    if isRunning {
                        Circle().fill(statusDotColor)
                            .frame(width: 7, height: 7)
                            .opacity(blinkToggle ? 1 : 0.2)
                            .animation(.easeInOut(duration: 0.6), value: blinkToggle)
                    }
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white).tracking(2)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())

                Spacer()

                // Live XP badge
                VStack(spacing: 0) {
                    Text("+\(liveXP)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(gold)
                    Text("XP")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(gold.opacity(0.6))
                }
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
            }

            // Elevation XP progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12)).frame(height: 5)
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
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white.opacity(0.4)).tracking(1.5)
                    } else {
                        Text("ELEVATION XP")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white.opacity(0.4)).tracking(1.5)
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

    // MARK: - Data Panel (Glassmorphism)

    private var dataPanel: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            VStack(spacing: 20) {
                if panelCollapsed {
                    // === COMPACT MODE: Key stats inline + controls ===
                    HStack(spacing: 16) {
                        // Elevation compact
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(Int(gpsManager.elevationGain))")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(gold)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: Int(gpsManager.elevationGain))
                            Text("Hm")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(gold.opacity(0.6))
                        }

                        Spacer()

                        // Time compact
                        Text(timeString(from: timeElapsed))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        // Distance compact
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", gpsManager.distance / 1000))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("km")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Compact controls
                    if timeElapsed == 0 && !isRunning {
                        Button(action: startRecording) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .black))
                                Text("START MISSION")
                                    .font(.system(size: 14, weight: .black)).tracking(2)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(gold)
                            .cornerRadius(28)
                            .shadow(color: gold.opacity(0.4), radius: 16, y: 6)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Button(action: togglePause) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .bold))
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
                    // === EXPANDED MODE: Full stats ===

                    // === PRIMARY: Elevation Gain ===
                    VStack(spacing: 2) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(Int(gpsManager.elevationGain))")
                                .font(.system(size: 86, weight: .black, design: .rounded))
                                .foregroundColor(gold)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: Int(gpsManager.elevationGain))
                            Text("Hm")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(gold.opacity(0.6))
                                .padding(.bottom, 10)
                        }
                        Text("ELEVATION GAIN")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(0.35)).tracking(3)
                    }

                    // Divider
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.horizontal, 10)

                    // === SECONDARY: Time + Distance ===
                    HStack(spacing: 0) {
                        VStack(spacing: 5) {
                            Text(timeString(from: timeElapsed))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("DURATION")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.white.opacity(0.35)).tracking(2)
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 44)

                        VStack(spacing: 5) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(String(format: "%.2f", gpsManager.distance / 1000))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("km")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Text("DISTANCE")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.white.opacity(0.35)).tracking(2)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // === OPTIONAL: Mini elevation profile ===
                    if gpsManager.rawRoute.count >= 2 && showElevationProfile {
                        ElevationProfileChart(locations: gpsManager.rawRoute)
                            .frame(height: 60)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // === CONTROLS ===
                    if timeElapsed == 0 && !isRunning {
                        Button(action: startRecording) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .black))
                                Text("START MISSION")
                                    .font(.system(size: 14, weight: .black)).tracking(2)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(gold)
                            .cornerRadius(28)
                            .shadow(color: gold.opacity(0.4), radius: 16, y: 6)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Button(action: togglePause) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }

                            if gpsManager.rawRoute.count >= 2 {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showElevationProfile.toggle()
                                    }
                                }) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(showElevationProfile ? gold : .white)
                                        .frame(width: 56, height: 56)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
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
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 30, y: -10)
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

    // MARK: - Actions (connected to existing backend)

    private func startRecording() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isRunning = true
        gpsManager.logManualResume()
        gpsManager.startTracking()
    }

    private func togglePause() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
// === Prevents accidental tour ending ===
// =========================================

struct SlideToFinishControl: View {
    var onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isCompleted = false

    private let thumbSize: CGFloat = 48
    private let trackHeight: CGFloat = 56
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        GeometryReader { geo in
            let maxDrag = geo.size.width - thumbSize - 8

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.red.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.red.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(
                        Text("SLIDE TO FINISH")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(max(0.35 - (dragOffset / maxDrag) * 0.35, 0)))
                            .tracking(2)
                    )

                // Progress fill
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.red.opacity(0.15))
                    .frame(width: dragOffset + thumbSize + 8)

                // Thumb
                ZStack {
                    Circle()
                        .fill(Color(red: 0.25, green: 0.06, blue: 0.06))
                        .frame(width: thumbSize, height: thumbSize)
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                        .frame(width: thumbSize, height: thumbSize)
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 16, weight: .bold))
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
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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

    // === DER GIPFEL-CHECK ===
    // (Wir sagen einfach: Wenn er mindestens 80% der Höhenmeter des Berges geschafft hat, gilt es als geschafft!)
    var isVerifiedSummit: Bool {
        guard let mountain = targetMountain else { return false }
        return elevationMeters >= Int(Double(mountain.elevation) * 0.8)
    }

    // Basis XP + Bonus XP wenn verifiziert
    var xpGained: Int {
        let baseXP = 100 + elevationMeters
        return isVerifiedSummit ? baseXP + 500 : baseXP
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: durationSeconds) ?? "0m"
    }

    var body: some View {
        NavigationView {
            Form {
                // === DIE NEUE VERIFIKATIONS-ANZEIGE ===
                if let mountain = targetMountain {
                    Section {
                        HStack {
                            if isVerifiedSummit {
                                Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.title)
                                VStack(alignment: .leading) {
                                    Text("Verified Summit").font(.headline).foregroundColor(.green)
                                    Text("You conquered \(mountain.name)! (+500 Bonus XP)").font(.caption).foregroundColor(.gray)
                                }
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.title)
                                VStack(alignment: .leading) {
                                    Text("Mission Attempt").font(.headline).foregroundColor(.orange)
                                    Text("Elevation too low to verify summit.").font(.caption).foregroundColor(.gray)
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
                    .onChange(of: photoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                await MainActor.run { self.photoData = data }
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
                                    .font(.caption).foregroundColor(.orange)
                                Text(pause.isAutomatic ? "Auto" : "Manual")
                                    .font(.subheadline)
                                Spacer()
                                Text(formatPauseDuration(pause.duration))
                                    .font(.subheadline).foregroundColor(.gray)
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
        .preferredColorScheme(.dark)
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
// === Live chart during tracking ===
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

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

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
                AxisValueLabel().foregroundStyle(.gray).font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel().foregroundStyle(.gray).font(.system(size: 9))
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }
}
