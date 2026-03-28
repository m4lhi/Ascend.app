import SwiftUI
import MapKit
import Combine
import CoreLocation
import CoreMotion
import Charts

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

    private var statusLabel: String {
        if isRunning && gpsManager.isAutoPaused { return "AUTO-PAUSED" }
        if isRunning { return "RECORDING" }
        return targetMountain?.name.uppercased() ?? "FREERIDE"
    }

    private var statusColor: Color {
        if isRunning && gpsManager.isAutoPaused { return .orange }
        if isRunning { return .red }
        return .gray
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

            VStack {
                HStack {
                    if isRunning {
                        Circle()
                            .fill(gpsManager.isAutoPaused ? Color.orange : Color.red)
                            .frame(width: 10, height: 10)
                            .shadow(color: gpsManager.isAutoPaused ? .orange : .red, radius: 5)
                            .opacity(blinkToggle ? 1.0 : 0.3)
                            .animation(.easeInOut, value: blinkToggle)
                    }
                    Text(statusLabel)
                        .font(.caption).fontWeight(.bold).foregroundColor(statusColor).tracking(2)

                    Spacer()
                    Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 32)).foregroundColor(.white.opacity(0.5)) }
                }
                .padding(.horizontal, 25).padding(.top, 20)

                Spacer().frame(height: 30)

                Text(timeString(from: timeElapsed)).font(.system(size: 64, weight: .light, design: .monospaced)).foregroundColor(.white)

                Map(position: $cameraPosition) {
                    UserAnnotation()
                    if !gpsManager.routePoints.isEmpty {
                        MapPolyline(coordinates: gpsManager.routePoints)
                            .stroke(Color(red: 0.85, green: 0.65, blue: 0.13), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }
                .preferredColorScheme(.dark).frame(height: 250).cornerRadius(25).padding(.horizontal, 25).padding(.top, 20)
                .shadow(color: .black.opacity(0.3), radius: 15, y: 10)

                HStack(spacing: 50) {
                    VStack(spacing: 8) {
                        Text("\(Int(gpsManager.elevationGain))m").font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text("ELEVATION").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                    }
                    VStack(spacing: 8) {
                        Text(String(format: "%.1f km", gpsManager.distance / 1000)).font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text("DISTANCE").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 30)

                // Live elevation profile (appears once recording has ≥ 2 GPS points)
                if gpsManager.rawRoute.count >= 2 {
                    ElevationProfileChart(locations: gpsManager.rawRoute)
                        .frame(height: 80)
                        .padding(.horizontal, 25)
                }

                Spacer()

                HStack(spacing: 30) {
                    if !isRunning && timeElapsed > 0 {
                        Button(action: endMission) {
                            Image(systemName: "stop.fill").font(.title).foregroundColor(.white).frame(width: 70, height: 70)
                                .background(Color.red).clipShape(Circle()).shadow(color: .red.opacity(0.5), radius: 10, y: 5)
                        }
                    }

                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        isRunning.toggle()
                        if isRunning {
                            gpsManager.logManualResume()
                            gpsManager.startTracking()
                        } else {
                            gpsManager.stopTracking()
                            gpsManager.logManualPause()
                        }
                    }) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill").font(.system(size: 32, weight: .black)).foregroundColor(.black)
                            .frame(width: 90, height: 90).background(Color(red: 0.85, green: 0.65, blue: 0.13)).clipShape(Circle())
                            .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.5), radius: 15, y: 5)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onReceive(timer) { _ in
            blinkToggle.toggle()
            if isRunning && !gpsManager.isAutoPaused { timeElapsed += 1 }
        }
        .sheet(isPresented: $showSaveForm) {
            // Wir übergeben jetzt den KOMPLETTEN Berg an das Formular
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

    func timeString(from seconds: Int) -> String {
        let h = seconds / 3600; let m = (seconds % 3600) / 60; let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    func endMission() {
        isRunning = false
        gpsManager.stopTracking()
        gpsManager.finalizeSession() // apply post-hoc smoothing before the save form reads elevationGain
        showSaveForm = true
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
                            pauses: pauseLog
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
