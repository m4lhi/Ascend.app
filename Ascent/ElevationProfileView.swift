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
    
    @State private var selectedDistance: Double?

    private var elevationData: [ElevationPoint] {
        generateElevationData(from: routePoints)
    }

    private var totalAscent: Double {
        var gain: Double = 0
        for i in 1..<routePoints.count {
            let delta = routePoints[i].altitude - routePoints[i-1].altitude
            if delta > 0 { gain += delta }
        }
        return gain
    }

    private var totalDescent: Double {
        var loss: Double = 0
        for i in 1..<routePoints.count {
            let delta = routePoints[i].altitude - routePoints[i-1].altitude
            if delta < 0 { loss += abs(delta) }
        }
        return loss
    }

    private var maxAltitude: Double {
        routePoints.map(\.altitude).max() ?? 0
    }

    private var minAltitude: Double {
        routePoints.map(\.altitude).min() ?? 0
    }

    private var totalDistance: Double {
        elevationData.last?.distance ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            if !compact {
                // Mini Interactive Map
                if !routePoints.isEmpty {
                    Map(interactionModes: []) {
                        MapPolyline(coordinates: routePoints.map { $0.coordinate })
                            .stroke(DesignSystem.Colors.accent.opacity(0.8), lineWidth: 4)

                        if let sel = selectedDistance, 
                           let point = elevationData.min(by: { abs($0.distance - sel) < abs($1.distance - sel) }) {
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
                    .animation(.default, value: selectedDistance)
                }

                // Stats row
                HStack(spacing: 16) {
                    StatPill(icon: "arrow.up", value: "\(Int(totalAscent))m", label: "Ascent", color: .orange)
                    StatPill(icon: "arrow.down", value: "\(Int(totalDescent))m", label: "Descent", color: .cyan)
                    StatPill(icon: "mountain.2.fill", value: "\(Int(maxAltitude))m", label: "Max", color: .purple)
                    StatPill(icon: "ruler", value: String(format: "%.1f km", totalDistance), label: "Distance", color: .blue)
                }
            }

            // Chart Top HUD (Komoot-Style)
            if !compact {
                HStack {
                    if let sel = selectedDistance, let point = elevationData.min(by: { abs($0.distance - sel) < abs($1.distance - sel) }) {
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
            if !elevationData.isEmpty {
                chartView
                    .frame(height: compact ? 120 : 200)
                    .padding(.trailing, 14)
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
    }

    // MARK: - Chart View (extracted to help Swift type-checker)

    private var chartView: some View {
        let baseAlt: Double = minAltitude - 50
        let topAlt: Double = maxAltitude + 50

        return Chart {
            ForEach(elevationData) { point in
                areaFor(point: point, base: baseAlt)
                lineFor(point: point)
            }

            if let pos = currentPosition {
                RuleMark(x: .value("Position", pos))
                    .foregroundStyle(.white)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            
            if let sel = selectedDistance, let point = elevationData.min(by: { abs($0.distance - sel) < abs($1.distance - sel) }) {
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
                                let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                if let distance: Double = proxy.value(atX: x) {
                                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                                        selectedDistance = distance
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) { selectedDistance = nil }
                            }
                    )
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...(totalDistance > 0 ? totalDistance : 1))
        .chartYScale(domain: baseAlt...topAlt)
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                AxisValueLabel {
                    if let ds = value.as(Double.self) {
                        Text(String(format: "%.0f km", ds)).font(.system(size: 10, design: .rounded))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                AxisValueLabel {
                    if let alt = value.as(Double.self) {
                        Text("\(Int(alt)) m").font(.system(size: 10, design: .rounded))
                    }
                }
            }
        }
    }

    private func areaFor(point: ElevationPoint, base: Double) -> some ChartContent {
        let color = point.segment.color
        return AreaMark(
            x: .value("Distance", point.distance),
            yStart: .value("Base", base),
            yEnd: .value("Altitude", point.altitude)
        )
        .foregroundStyle(
            LinearGradient(
                colors: [color.opacity(0.3), color.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func lineFor(point: ElevationPoint) -> some ChartContent {
        LineMark(
            x: .value("Distance", point.distance),
            y: .value("Altitude", point.altitude)
        )
        .foregroundStyle(point.segment.color)
        .lineStyle(StrokeStyle(lineWidth: 2))
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
        let total = Double(elevationData.count)
        guard total > 0 else { return [] }

        var counts: [TrailSegment: Int] = [:]
        for point in elevationData {
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
