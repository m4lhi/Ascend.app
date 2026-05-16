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
                            ProgressView().tint(DesignSystem.Colors.inkWarm.opacity(0.62))
                            Text("Loading alpine forecast…")
                                .font(DesignSystem.Typography.subheadInter)
                                .foregroundStyle(DesignSystem.Colors.inkWarm)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(Capsule().fill(DesignSystem.Colors.paperWarm.opacity(0.95)))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
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
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.paperWarm.opacity(0.95))
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                }
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            }

            Spacer()

            VStack(spacing: 1) {
                Text("Alpine safety")
                    .font(DesignSystem.Typography.kickerInter)
                    .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                Text(appState.activeMountain?.name ?? "Target region")
                    .font(DesignSystem.Typography.bodyEmphasisInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 8)
            .background(Capsule().fill(DesignSystem.Colors.paperWarm.opacity(0.95)))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            Spacer()

            safetyBadge
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
    }

    @ViewBuilder
    private var safetyBadge: some View {
        let safety = weather.currentWeather?.safetyLevel ?? .good
        HStack(spacing: 5) {
            Circle()
                .fill(safety.pastelColor)
                .frame(width: 6, height: 6)
            Text(safety.sentenceLabel)
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 8)
        .background(Capsule().fill(safety.pastelSoftColor))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            layerPicker
            avalancheCard
            alpineTelemetry
            hourlyScrubber
            hourlyStrip
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(DesignSystem.Colors.paperWarm)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    // MARK: Avalanche Bulletin Card
    @ViewBuilder
    private var avalancheCard: some View {
        if let b = avalancheBulletin {
            Button { showAvalancheHeatmap = true } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // EAWS danger-rating circle keeps its official 1–5 colour
                    // scale; that hex is functional, not stylistic.
                    ZStack {
                        Circle()
                            .fill(Color(hex: b.dangerColorHex) ?? .gray)
                            .frame(width: 44, height: 44)
                        Text("\(b.dangerLevel)")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(b.dangerLevel >= 4 ? .white : .black)
                            .monospacedDigit()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avalanche · \(b.dangerLabel.capitalized)")
                            .font(DesignSystem.Typography.kickerInter)
                            .foregroundStyle(DesignSystem.Colors.ember)
                        Text(b.regionName)
                            .font(DesignSystem.Typography.bodyEmphasisInter)
                            .foregroundStyle(DesignSystem.Colors.inkWarm)
                            .lineLimit(1)
                        if !b.problems.isEmpty {
                            Text(b.problems.prefix(2).joined(separator: ", ").replacingOccurrences(of: "_", with: " "))
                                .font(DesignSystem.Typography.kickerInter)
                                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.alpenglowSoft.opacity(0.5))
                )
            }
            .buttonStyle(.plain)
        } else if avalancheLoading {
            HStack(spacing: 10) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(DesignSystem.Colors.inkWarm.opacity(0.62))
                Text("Loading avalanche bulletin…")
                    .font(DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                Spacer()
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.surfaceWarm)
            )
        } else {
            HStack(spacing: 8) {
                Circle()
                    .fill(DesignSystem.Colors.meadow)
                    .frame(width: 8, height: 8)
                Text("No avalanche bulletin issued for this region.")
                    .font(DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
                Spacer()
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.meadowSoft.opacity(0.5))
            )
        }
    }

    // MARK: Layer Picker

    private var layerPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Layer.allCases, id: \.self) { l in
                    Button {
                        withAnimation(DesignSystem.Animations.quick) { layer = l }
                        HapticManager.shared.light()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: l.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(l.rawValue)
                                .font(DesignSystem.Typography.kickerInter)
                        }
                        .foregroundStyle(layer == l
                                         ? DesignSystem.Colors.inkOnSand
                                         : DesignSystem.Colors.inkWarm.opacity(0.62))
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                layer == l
                                    ? DesignSystem.Colors.alpenglow
                                    : DesignSystem.Colors.surfaceWarm
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 2)
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
                label: "Precip",
                value: String(format: "%.0f%%", (h?.precipitationChance ?? 0) * 100),
                active: layer == .rain
            )
            telemetryDivider
            telemetryCell(
                label: "Wind",
                value: "\(Int(h?.windSpeed ?? 0)) km/h",
                active: layer == .wind
            )
            telemetryDivider
            telemetryCell(
                label: "Temp",
                value: "\(Int(h?.temperature ?? 0))°C",
                active: layer == .temp
            )
            telemetryDivider
            telemetryCell(
                label: "Chill",
                value: "\(Int(windChill))°C",
                active: false
            )
            telemetryDivider
            telemetryCell(
                label: "0° lvl",
                value: "\(freezingLevel) m",
                active: false
            )
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.surfaceWarm)
        )
    }

    private func telemetryCell(label: String, value: String, active: Bool) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(DesignSystem.Typography.subheadInter.weight(.semibold))
                .foregroundStyle(active
                                 ? DesignSystem.Colors.alpenglow
                                 : DesignSystem.Colors.inkWarm)
                .monospacedDigit()
            Text(label)
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
        }
        .frame(maxWidth: .infinity)
    }

    private var telemetryDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.borderSubtle)
            .frame(width: 0.5, height: 28)
    }

    // MARK: Hourly Scrubber

    private var hourlyScrubber: some View {
        VStack(spacing: 4) {
            if hourly.count < 2 {
                HStack(spacing: 8) {
                    if weather.isLoading {
                        ProgressView().tint(DesignSystem.Colors.alpenglow).scaleEffect(0.8)
                        Text("Loading forecast…")
                    } else {
                        Text("No forecast available")
                    }
                }
                .font(DesignSystem.Typography.subheadInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
            } else {
                Slider(
                    value: $selectedHourOffset,
                    in: 0...Double(hourly.count - 1),
                    step: 1
                )
                .tint(DesignSystem.Colors.alpenglow)

                HStack {
                    Text("Now")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                    Spacer()
                    if let h = selectedHour {
                        Text(timeLabel(h.hour))
                            .font(DesignSystem.Typography.kickerInter.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.alpenglow)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text("+\(hourly.count)h")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                        .monospacedDigit()
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
            withAnimation(DesignSystem.Animations.quick) {
                selectedHourOffset = Double(idx)
            }
            HapticManager.shared.light()
        } label: {
            VStack(spacing: 2) {
                Text(shortHour(hour.hour))
                    .font(DesignSystem.Typography.kickerInter)
                    .foregroundStyle(selected
                                     ? DesignSystem.Colors.inkOnSand
                                     : DesignSystem.Colors.inkWarm.opacity(0.62))
                    .monospacedDigit()
                Image(systemName: hour.conditionSymbol)
                    .font(.system(size: 12))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(selected
                                     ? DesignSystem.Colors.inkOnSand
                                     : DesignSystem.Colors.inkWarm)
                Text("\(Int(hour.temperature))°")
                    .font(DesignSystem.Typography.kickerInter.weight(.semibold))
                    .foregroundStyle(selected
                                     ? DesignSystem.Colors.inkOnSand
                                     : DesignSystem.Colors.inkWarm)
                    .monospacedDigit()
                RoundedRectangle(cornerRadius: 1)
                    .fill(rainBarColor(hour.precipitationChance))
                    .frame(width: 16, height: max(2, CGFloat(hour.precipitationChance) * 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected
                          ? DesignSystem.Colors.alpenglow
                          : (danger ? DesignSystem.Colors.ember.opacity(0.10) : DesignSystem.Colors.surfaceWarm))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(danger && !selected
                            ? DesignSystem.Colors.ember.opacity(0.30)
                            : Color.clear,
                            lineWidth: 1)
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
