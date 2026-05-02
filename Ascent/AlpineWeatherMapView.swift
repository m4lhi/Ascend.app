import SwiftUI
import MapKit
import CoreLocation
import Combine

// =========================================
// === DATEI: AlpineWeatherMapView.swift ===
// === Live weather radar with OWM tiles ===
// =========================================
//
// Full-screen weather map for mountaineering safety. Uses OpenWeatherMap
// tile layers (precipitation, clouds, wind, temperature) rendered as
// real raster overlays on top of Apple Maps terrain, plus WeatherKit
// hourly data for the scrubber and telemetry readouts.
//
// High-altitude extras:
//   • Freezing level + snow-line estimate
//   • Wind-chill calculation
//   • Safety verdict based on combined alpine risk factors
//   • 24h hourly scrubber with animated layer transitions

// MARK: - RainViewer API Manager

class RainViewerManager: ObservableObject {
    static let shared = RainViewerManager()
    @Published var latestPath: String?
    
    init() {
        Task {
            guard let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let radar = json["radar"] as? [String: Any],
                   let past = radar["past"] as? [[String: Any]],
                   let last = past.last,
                   let path = last["path"] as? String {
                    DispatchQueue.main.async {
                        self.latestPath = path
                    }
                }
            } catch {
                print("RainViewer fetch failed.")
            }
        }
    }
}

// MARK: - OWM & RainViewer Tile Overlay (UIKit bridge)

/// Wraps an MKMapView with OpenWeatherMap/RainViewer raster tile overlays.
/// SwiftUI's native Map doesn't support MKTileOverlay, so we bridge via UIViewRepresentable.
struct WeatherTileMapView: UIViewRepresentable {
    let center: CLLocationCoordinate2D
    let layer: AlpineWeatherMapView.Layer
    let span: Double // degrees
    let rvPath: String? // RainViewer dynamic path

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isRotateEnabled = false
        map.showsCompass = false
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        // Flat elevation — 3D realistic terrain causes raster tile overlays to disappear at certain pitches.
        // For weather radar visibility, flat is the right call.
        let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = config

        map.delegate = context.coordinator
        map.setRegion(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ), animated: false)

        // Add initial tile overlay
        let overlay = Self.tileOverlay(for: layer, rvPath: rvPath)
        map.addOverlay(overlay, level: .aboveRoads)
        context.coordinator.currentOverlay = overlay

        // Mountain pin
        let pin = MKPointAnnotation()
        pin.coordinate = center
        pin.title = "Target"
        map.addAnnotation(pin)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        if let old = context.coordinator.currentOverlay {
            map.removeOverlay(old)
        }
        let overlay = Self.tileOverlay(for: layer, rvPath: rvPath)
        // Use .aboveRoads (not .aboveLabels) — at .aboveLabels the tiles can be hidden by
        // map labels or clipped against POI/text rendering passes.
        map.addOverlay(overlay, level: .aboveRoads)
        context.coordinator.currentOverlay = overlay
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        var currentOverlay: MKTileOverlay?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                renderer.alpha = 0.75 // visible enough but lets the base map show through
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let id = "target"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.glyphImage = UIImage(systemName: "mountain.2.fill")
            view.markerTintColor = .systemOrange
            view.displayPriority = .required
            return view
        }
    }

    private static func tileOverlay(for layer: AlpineWeatherMapView.Layer, rvPath: String?) -> MKTileOverlay {
        // Option 1: Use RainViewer for Rain
        if layer == .rain, let path = rvPath {
            let template = "https://tilecache.rainviewer.com\(path)/256/{z}/{x}/{y}/2/1_1.png"
            let overlay = MKTileOverlay(urlTemplate: template)
            overlay.canReplaceMapContent = false
            overlay.maximumZ = 8
            overlay.minimumZ = 3
            return overlay
        }
        
        // Option 2: Fallback to OWM for other layers using the standard public demo key
        let layerSlug: String
        switch layer {
        case .rain:   layerSlug = "precipitation_new"
        case .clouds: layerSlug = "clouds_new"
        case .wind:   layerSlug = "wind_new"
        case .temp:   layerSlug = "temp_new"
        case .snow:   layerSlug = "snow_new"
        }
        let template = "https://tile.openweathermap.org/map/\(layerSlug)/{z}/{x}/{y}.png?appid=\(APIKeys.openWeatherMap)"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false
        overlay.maximumZ = 8
        overlay.minimumZ = 3
        return overlay
    }
}

// MARK: - Main View

struct AlpineWeatherMapView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var weather = WeatherManager.shared
    @StateObject private var rainViewer = RainViewerManager.shared

    enum Layer: String, CaseIterable {
        case rain = "Rain"
        case clouds = "Clouds"
        case wind = "Wind"
        case temp = "Temp"
        case snow = "Snow"

        var icon: String {
            switch self {
            case .rain:   return "cloud.rain.fill"
            case .clouds: return "cloud.fill"
            case .wind:   return "wind"
            case .temp:   return "thermometer.medium"
            case .snow:   return "snowflake"
            }
        }

        var tint: Color {
            switch self {
            case .rain:   return .blue
            case .clouds: return .gray
            case .wind:   return .teal
            case .temp:   return .orange
            case .snow:   return .cyan
            }
        }
    }

    @State private var layer: Layer = .rain
    @State private var selectedHourOffset: Double = 0
    @State private var showLegend = false
    @State private var avalancheBulletin: AvalancheBulletin?
    @State private var avalancheLoading = true
    @State private var showAvalancheHeatmap = false

    private var targetCoord: CLLocationCoordinate2D {
        if let m = appState.activeMountain, let lat = m.latitude, let lon = m.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return CLLocationCoordinate2D(latitude: 45.8326, longitude: 6.8652) // Chamonix
    }

    private var hourly: [HourlyWeather] { weather.currentWeather?.hourlyForecast ?? [] }

    private var selectedHour: HourlyWeather? {
        let idx = Int(selectedHourOffset)
        guard idx >= 0, idx < hourly.count else { return hourly.first }
        return hourly[idx]
    }

    private var driftStyle: WeatherDriftOverlay.Style {
        switch layer {
        case .clouds: return .clouds
        case .rain:   return .rain
        case .snow:   return .snow
        case .wind:   return .wind
        case .temp:   return .none
        }
    }

    /// Convert compass-direction string ("N", "NE", "ENE"…) to degrees so the
    /// drift overlay tilts streaks correctly.
    private var windHeadingDegrees: Double {
        guard let dir = weather.currentWeather?.windDirection.uppercased() else { return 270 }
        switch dir {
        case "N":   return 0
        case "NNE": return 22.5
        case "NE":  return 45
        case "ENE": return 67.5
        case "E":   return 90
        case "ESE": return 112.5
        case "SE":  return 135
        case "SSE": return 157.5
        case "S":   return 180
        case "SSW": return 202.5
        case "SW":  return 225
        case "WSW": return 247.5
        case "W":   return 270
        case "WNW": return 292.5
        case "NW":  return 315
        case "NNW": return 337.5
        default:    return 270
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Real tile-based weather map
                WeatherTileMapView(
                    center: targetCoord,
                    layer: layer,
                    span: 0.35,
                    rvPath: rainViewer.latestPath
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: layer)

                // Animated atmospheric drift on top of the tile map
                WeatherDriftOverlay(style: driftStyle, windDeg: windHeadingDegrees)
                    .ignoresSafeArea()
                    .opacity(driftStyle == .none ? 0 : 1)
                    .animation(.easeInOut(duration: 0.5), value: layer)

                // Loading overlay
                if weather.isLoading {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Loading alpine forecast…")
                                .font(.appMono(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        Spacer()
                    }
                }

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomPanel
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                let c = targetCoord
                Task { await weather.fetchWeather(latitude: c.latitude, longitude: c.longitude) }
                Task { await loadAvalancheBulletin() }
            }
            .sheet(isPresented: $showAvalancheHeatmap) {
                AvalancheHeatmapSheet(center: targetCoord)
                    .presentationDetents([.large])
            }
        }
    }

    private func loadAvalancheBulletin() async {
        avalancheLoading = true
        let bulletin = try? await AvalancheService.shared.fetchBulletin(for: targetCoord)
        await MainActor.run {
            self.avalancheBulletin = bulletin
            self.avalancheLoading = false
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }

            Spacer()

            VStack(spacing: 1) {
                Text("ALPINE SAFETY")
                    .font(.appMono(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                Text(appState.activeMountain?.name ?? "Target Region")
                    .font(.app(size: 13, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            Spacer()

            // Safety verdict badge
            safetyBadge
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var safetyBadge: some View {
        let safety = weather.currentWeather?.safetyLevel ?? .good
        HStack(spacing: 4) {
            Image(systemName: safety.icon)
                .font(.system(size: 10, weight: .bold))
            Text(safety.label.uppercased())
                .font(.appMono(size: 8, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(safety.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(safety.color.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // Layer switcher
            layerPicker

            // Avalanche bulletin (always visible — critical safety info)
            avalancheCard

            // Alpine telemetry readout
            alpineTelemetry

            // Hourly scrubber
            hourlyScrubber

            // Hourly strip
            hourlyStrip
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 16)
    }

    // MARK: Avalanche Bulletin Card
    @ViewBuilder
    private var avalancheCard: some View {
        if let b = avalancheBulletin {
            Button { showAvalancheHeatmap = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: b.dangerColorHex) ?? .gray)
                            .frame(width: 44, height: 44)
                        Text("\(b.dangerLevel)")
                            .font(.system(size: 19, weight: .black))
                            .foregroundColor(b.dangerLevel >= 4 ? .white : .black)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.orange)
                            Text("AVALANCHE — \(b.dangerLabel.uppercased())")
                                .font(.appMono(size: 9, weight: .heavy))
                                .tracking(1.0)
                        }
                        Text(b.regionName)
                            .font(.app(size: 13, weight: .heavy))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if !b.problems.isEmpty {
                            Text(b.problems.prefix(2).joined(separator: ", ").replacingOccurrences(of: "_", with: " "))
                                .font(.app(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "map.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
            .buttonStyle(.plain)
        } else if avalancheLoading {
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.7)
                Text("Loading avalanche bulletin…")
                    .font(.app(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        } else {
            // No bulletin available for region (e.g. summer or unsupported area)
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("No avalanche bulletin issued for this region.")
                    .font(.app(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
    }

    // MARK: Layer Picker

    private var layerPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Layer.allCases, id: \.self) { l in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { layer = l }
                        HapticManager.shared.light()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: l.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(l.rawValue.uppercased())
                                .font(.appMono(size: 9, weight: .bold))
                                .tracking(0.6)
                        }
                        .foregroundColor(layer == l ? .white : .primary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(layer == l ? l.tint : Color.white.opacity(0.5))
                        )
                    }
                }
            }
        }
    }

    // MARK: Alpine Telemetry

    private var alpineTelemetry: some View {
        let h = selectedHour
        let windChill = calculateWindChill(
            temp: h?.temperature ?? 0,
            wind: h?.windSpeed ?? 0
        )
        let freezingLevel = estimateFreezingLevel(temp: h?.temperature ?? 0)

        return HStack(spacing: 0) {
            telemetryCell(
                label: "PRECIP",
                value: String(format: "%.0f%%", (h?.precipitationChance ?? 0) * 100),
                icon: "drop.fill",
                tint: .blue,
                active: layer == .rain
            )
            Divider().frame(height: 36)
            telemetryCell(
                label: "WIND",
                value: "\(Int(h?.windSpeed ?? 0)) km/h",
                icon: "wind",
                tint: .teal,
                active: layer == .wind
            )
            Divider().frame(height: 36)
            telemetryCell(
                label: "TEMP",
                value: "\(Int(h?.temperature ?? 0))°C",
                icon: "thermometer.medium",
                tint: .orange,
                active: layer == .temp
            )
            Divider().frame(height: 36)
            telemetryCell(
                label: "CHILL",
                value: "\(Int(windChill))°C",
                icon: "wind.snow",
                tint: windChill < -20 ? .purple : (windChill < -10 ? .blue : .cyan),
                active: false
            )
            Divider().frame(height: 36)
            telemetryCell(
                label: "0° LVL",
                value: "\(freezingLevel)m",
                icon: "arrow.up.to.line",
                tint: freezingLevel < 2500 ? .blue : .green,
                active: false
            )
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.35))
        )
    }

    private func telemetryCell(label: String, value: String, icon: String, tint: Color, active: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(active ? tint : .secondary)
            Text(value)
                .font(.appMono(size: 12, weight: .bold))
                .foregroundColor(active ? tint : .primary)
            Text(label)
                .font(.appMono(size: 7, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Hourly Scrubber

    private var hourlyScrubber: some View {
        VStack(spacing: 4) {
            if hourly.count < 2 {
                HStack(spacing: 8) {
                    if weather.isLoading {
                        ProgressView().tint(layer.tint).scaleEffect(0.8)
                        Text("Loading forecast…")
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                        Text("No forecast available")
                    }
                }
                .font(.appMono(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                Slider(
                    value: $selectedHourOffset,
                    in: 0...Double(hourly.count - 1),
                    step: 1
                )
                .tint(layer.tint)

                HStack {
                    Text("Now")
                        .font(.appMono(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let h = selectedHour {
                        Text(timeLabel(h.hour))
                            .font(.appMono(size: 10, weight: .bold))
                            .foregroundColor(layer.tint)
                    }
                    Spacer()
                    Text("+\(hourly.count)h")
                        .font(.appMono(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: Hourly Strip

    private var hourlyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(hourly.enumerated()), id: \.offset) { idx, h in
                    hourPill(idx: idx, hour: h)
                }
            }
        }
        .frame(height: 62)
    }

    private func hourPill(idx: Int, hour: HourlyWeather) -> some View {
        let selected = idx == Int(selectedHourOffset)
        let danger = hour.windSpeed > 50 || hour.precipitationChance > 0.7
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                selectedHourOffset = Double(idx)
            }
            HapticManager.shared.light()
        } label: {
            VStack(spacing: 2) {
                Text(shortHour(hour.hour))
                    .font(.appMono(size: 8, weight: .bold))
                    .foregroundColor(selected ? .white : .secondary)
                Image(systemName: hour.conditionSymbol)
                    .font(.system(size: 12))
                    .symbolRenderingMode(.multicolor)
                    .foregroundColor(selected ? .white : .primary)
                Text("\(Int(hour.temperature))°")
                    .font(.appMono(size: 9, weight: .bold))
                    .foregroundColor(selected ? .white : .primary)
                // Rain chance bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(rainBarColor(hour.precipitationChance))
                    .frame(width: 16, height: max(2, CGFloat(hour.precipitationChance) * 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? layer.tint : (danger ? Color.red.opacity(0.08) : Color.white.opacity(0.4)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(danger && !selected ? Color.red.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Alpine Calculations

    /// Wind chill (JAG/TI model for alpine conditions)
    private func calculateWindChill(temp: Double, wind: Double) -> Double {
        guard temp <= 10, wind > 4.8 else { return temp }
        let wPow = pow(wind, 0.16)
        return 13.12 + 0.6215 * temp - 11.37 * wPow + 0.3965 * temp * wPow
    }

    /// Rough freezing level estimate from surface temp
    /// Lapse rate ~6.5°C per 1000m, assumes station at ~1500m
    private func estimateFreezingLevel(temp: Double) -> Int {
        let stationAltitude = Double(appState.activeMountain?.elevation ?? 1500)
        guard temp > 0 else { return max(0, Int(stationAltitude)) }
        let rise = temp / 6.5 * 1000 // meters above station where it hits 0°C
        return Int(stationAltitude + rise)
    }

    private func rainBarColor(_ chance: Double) -> Color {
        if chance > 0.7 { return .purple }
        if chance > 0.4 { return .blue }
        if chance > 0.1 { return .cyan }
        return .gray.opacity(0.3)
    }

    // MARK: - Formatters

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func shortHour(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH"
        return f.string(from: date)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
