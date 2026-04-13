import SwiftUI
import Charts
import CoreLocation
import MapKit

// =========================================
// === DATEI: ElevationProfileView.swift ===
// === Höhenprofil mit Segmenten ===
// =========================================

struct ElevationPoint: Identifiable {
    let id = UUID()
    let distance: Double // km from start
    let altitude: Double // meters
    let gradient: Double // % steepness
    let segment: TrailSegment
    let coordinate: CLLocationCoordinate2D
}

enum TrailSegment: String, CaseIterable {
    case flat = "Flat"
    case moderate = "Moderate"
    case steep = "Steep"
    case verysteep = "Very Steep"
    case descent = "Descent"

    var color: Color {
        switch self {
        case .flat:      return .green
        case .moderate:  return .blue
        case .steep:     return .orange
        case .verysteep: return .red
        case .descent:   return .cyan
        }
    }

    var icon: String {
        switch self {
        case .flat:      return "arrow.right"
        case .moderate:  return "arrow.up.right"
        case .steep:     return "arrow.up"
        case .verysteep: return "arrow.up.circle.fill"
        case .descent:   return "arrow.down.right"
        }
    }

    static func fromGradient(_ gradient: Double) -> TrailSegment {
        if gradient < -5 { return .descent }
        if gradient < 8 { return .flat }
        if gradient < 15 { return .moderate }
        if gradient < 25 { return .steep }
        return .verysteep
    }
}

struct ElevationProfileView: View {
    let routePoints: [CLLocation]
    var currentPosition: Double? = nil // distance km from start for live tracker
    var compact: Bool = false
    var onCoordinateSelected: ((CLLocationCoordinate2D?) -> Void)? = nil
    
    @State private var selectedDistance: Double?
    @State private var zoomScale: Double = 1.0
    @State private var processTask: Task<Void, Never>? = nil
    
    struct RouteSegmentChunk: Identifiable {
        let id = UUID()
        let coords: [CLLocationCoordinate2D]
        let color: Color
    }
    
    struct ProfileState {
        var elevationData: [ElevationPoint] = []
        var totalAscent: Double = 0
        var totalDescent: Double = 0
        var maxAltitude: Double = 0
        var minAltitude: Double = 0
        var totalDistance: Double = 0
        var mapCoords: [CLLocationCoordinate2D] = []
        var gradientStops: [Gradient.Stop] = []
    }
    
    @State private var profile = ProfileState()

    private func processRouteData() {
        DispatchQueue.global(qos: .userInteractive).async {
            let data = generateElevationData(from: routePoints)
            
            var gain: Double = 0
            var loss: Double = 0
            for i in 1..<routePoints.count {
                let delta = routePoints[i].altitude - routePoints[i-1].altitude
                if delta > 0 { gain += delta } else { loss += abs(delta) }
            }
            
            let alts = routePoints.map(\.altitude)
            let maxAlt = alts.max() ?? 0
            let minAlt = alts.min() ?? 0
            
            let coords = routePoints.map(\.coordinate)
            
            let distance = data.last?.distance ?? 1.0
            let stops: [Gradient.Stop] = data.map { point in
                Gradient.Stop(color: point.segment.color, location: point.distance / distance)
            }
            
            let newState = ProfileState(
                elevationData: data,
                totalAscent: gain,
                totalDescent: loss,
                maxAltitude: maxAlt,
                minAltitude: minAlt,
                totalDistance: distance,
                mapCoords: coords,
                gradientStops: stops
            )
            
            DispatchQueue.main.async {
                self.profile = newState
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            if !compact {
                // Mini Interactive Map
                if !profile.mapCoords.isEmpty {
                    Map(interactionModes: []) {
                        MapPolyline(coordinates: profile.mapCoords)
                            .stroke(DesignSystem.Colors.accent.opacity(0.8), lineWidth: 4)

                        if let sel = selectedDistance,
                           let point = profile.elevationData.min(by: { abs($0.distance - sel) < abs($1.distance - sel) }) {
                            Annotation("", coordinate: point.coordinate) {
                                Circle()
                                    .fill(DesignSystem.Colors.accent)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Stats row
                HStack(spacing: 16) {
                    StatPill(icon: "arrow.up", value: "\(Int(profile.totalAscent))m", label: "Ascent", color: .orange)
                    StatPill(icon: "arrow.down", value: "\(Int(profile.totalDescent))m", label: "Descent", color: .cyan)
                    StatPill(icon: "mountain.2.fill", value: "\(Int(profile.maxAltitude))m", label: "Max", color: .purple)
                    StatPill(icon: "ruler", value: String(format: "%.1f km", profile.totalDistance), label: "Distance", color: .blue)
                }
            }

            // Chart Top HUD (Komoot-Style)
            if !compact {
                HStack {
                    if let sel = selectedDistance, let point = profile.elevationData.min(by: { abs($0.distance - sel) < abs($1.distance - sel) }) {
                        HStack(spacing: 14) {
                            HStack(spacing: 4) {
                                Image(systemName: "ruler").foregroundColor(.blue)
                                Text(String(format: "%.1f km", point.distance)).fontWeight(.bold)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right").foregroundColor(.orange)
                                Text("\(Int(point.altitude)) m").fontWeight(.bold)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(point.segment.color)
                                Text(String(format: "%.0f%%", point.gradient)).fontWeight(.bold).foregroundColor(point.segment.color)
                            }
                        }
                        .font(.system(size: 12, design: .rounded))
                        .animation(.none, value: point.id)
                    } else {
                        Text("Touch and drag chart for details")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                .frame(height: 16)
            }

            // Chart
            if !profile.elevationData.isEmpty {
                if compact {
                    chartView
                        .frame(height: 120)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                } else {
                    GeometryReader { geom in
                        ScrollView(.horizontal, showsIndicators: false) {
                            chartView
                                .frame(width: max(geom.size.width, geom.size.width * zoomScale))
                                .frame(height: 200)
                                .padding(.trailing, 24)
                                .padding(.leading, 12)
                                .padding(.vertical, 12)
                        }
                        .gesture(
                            MagnificationGesture()
                                .onChanged { val in
                                    zoomScale = max(1.0, min(5.0, val))
                                }
                        )
                    }
                    .frame(height: 200)
                }
            }

            // Segment legend
            if !compact {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(segmentSummary(), id: \.segment) { item in
                            HStack(spacing: 4) {
                                Circle().fill(item.segment.color).frame(width: 8, height: 8)
                                Text("\(item.segment.rawValue)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(String(format: "%.0f%%", item.percentage))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(compact ? 12 : 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            processRouteData()
        }
        .onChange(of: routePoints) { _, _ in
            // Debounce: don't recompute on every single GPS tick during live tracking
            processTask?.cancel()
            processTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                guard !Task.isCancelled else { return }
                processRouteData()
            }
        }
        .onChange(of: selectedDistance) { _, newDist in
            if let sel = newDist, let point = profile.elevationData.min(by: { abs($0.distance - sel) < abs($1.distance - sel) }) {
                onCoordinateSelected?(point.coordinate)
            } else {
                onCoordinateSelected?(nil)
            }
        }
    }

    // MARK: - Chart View (extracted to help Swift type-checker)

    private var chartSteepnessGradient: LinearGradient {
        guard !profile.gradientStops.isEmpty else {
            return LinearGradient(colors: [DesignSystem.Colors.accent], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(stops: profile.gradientStops, startPoint: .leading, endPoint: .trailing)
    }

    private var chartView: some View {
        let altRange = profile.maxAltitude - profile.minAltitude
        let pad = max(30, altRange * 0.15)
        let baseAlt: Double = profile.minAltitude - pad
        let topAlt: Double = profile.maxAltitude + pad

        return Chart {
            ForEach(profile.elevationData) { point in
                AreaMark(
                    x: .value("Distance", point.distance),
                    yStart: .value("Base", baseAlt),
                    yEnd: .value("Altitude", point.altitude)
                )
            }
            .foregroundStyle(chartSteepnessGradient.opacity(0.3))

            ForEach(profile.elevationData) { point in
                LineMark(
                    x: .value("Distance", point.distance),
                    y: .value("Altitude", point.altitude)
                )
            }
            .foregroundStyle(chartSteepnessGradient)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            if let pos = currentPosition {
                RuleMark(x: .value("Position", pos))
                    .foregroundStyle(.white)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            
            if let sel = selectedDistance, let point = profile.elevationData.min(by: { abs($0.distance - sel) < abs($1.distance - sel) }) {
                RuleMark(x: .value("Selected", point.distance))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("Selected Dist", point.distance),
                    y: .value("Selected Alt", point.altitude)
                )
                .foregroundStyle(DesignSystem.Colors.accent)
                .symbolSize(80)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotFrame!].origin.x
                                if let distance: Double = proxy.value(atX: x) {
                                    selectedDistance = distance
                                }
                            }
                            .onEnded { _ in
                                selectedDistance = nil
                            }
                    )
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...(profile.totalDistance > 0 ? profile.totalDistance : 1))
        .chartYScale(domain: baseAlt...topAlt)
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic(desiredCount: compact ? 3 : 5)) { value in
                AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                AxisValueLabel {
                    if let ds = value.as(Double.self) {
                        Text(String(format: "%.0f km", ds))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: compact ? 3 : 4)) { value in
                AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                AxisValueLabel {
                    if let alt = value.as(Double.self) {
                        Text("\(Int(alt)) m")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Data Generation

    private func generateElevationData(from points: [CLLocation]) -> [ElevationPoint] {
        guard points.count >= 2 else { return [] }

        var result: [ElevationPoint] = []
        var cumulativeDistance: Double = 0

        // Smooth altitudes first
        let smoothed = smoothAltitudes(points.map(\.altitude), window: 5)

        for i in 0..<points.count {
            if i > 0 {
                cumulativeDistance += points[i].distance(from: points[i-1]) / 1000
            }

            let gradient: Double
            if i > 0 {
                let horizontalDist = points[i].distance(from: points[i-1])
                let verticalDist = smoothed[i] - smoothed[i-1]
                gradient = horizontalDist > 0 ? (verticalDist / horizontalDist) * 100 : 0
            } else {
                gradient = 0
            }

            if i % max(1, points.count / 1000) == 0 || i == points.count - 1 {
                result.append(ElevationPoint(
                    distance: cumulativeDistance,
                    altitude: smoothed[i],
                    gradient: gradient,
                    segment: TrailSegment.fromGradient(gradient),
                    coordinate: points[i].coordinate
                ))
            }
        }

        return result
    }

    private func smoothAltitudes(_ altitudes: [Double], window: Int) -> [Double] {
        altitudes.enumerated().map { (i, _) in
            let start = max(0, i - window / 2)
            let end = min(altitudes.count - 1, i + window / 2)
            let slice = altitudes[start...end]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private struct SegmentSummary: Hashable {
        let segment: TrailSegment
        let percentage: Double
    }

    private func segmentSummary() -> [SegmentSummary] {
        let total = Double(profile.elevationData.count)
        guard total > 0 else { return [] }

        var counts: [TrailSegment: Int] = [:]
        for point in profile.elevationData {
            counts[point.segment, default: 0] += 1
        }

        return counts.map { SegmentSummary(segment: $0.key, percentage: Double($0.value) / total * 100) }
            .sorted { $0.percentage > $1.percentage }
    }
}

// MARK: - Stat Pill
private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
