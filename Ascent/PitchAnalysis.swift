import Foundation
import CoreLocation

// Pitch / slope angle analysis from a route's polyline + elevation profile.
// Outputs both percentage gradient AND true slope angles in degrees, plus
// the SAC/skitour-relevant zone breakdowns (30°, 35°, 40°, 45°+).
struct PitchAnalysis {
    let segments: [PitchSegment]
    let maxAngleDeg: Double
    let avgAngleDeg: Double
    let totalDistanceM: Double
    let totalAscentM: Int
    let totalDescentM: Int
    /// Distance (m) spent in each slope band — useful for skitour avalanche assessment.
    let distanceInBandsM: [SlopeBand: Double]

    var maxGradientPct: Double { tan(maxAngleDeg * .pi / 180) * 100 }
}

struct PitchSegment {
    let startCoord: CLLocationCoordinate2D
    let endCoord: CLLocationCoordinate2D
    let startElevationM: Double
    let endElevationM: Double
    let distanceM: Double
    let elevationDeltaM: Double
    let gradientPct: Double      // (rise / run) × 100
    let angleDeg: Double         // atan(rise / run) in degrees
    let band: SlopeBand
    let cumulativeDistanceM: Double  // running total from route start
}

enum SlopeBand: String, CaseIterable {
    case flat        = "Flat"        // < 10°
    case gentle      = "Gentle"      // 10–25°
    case moderate    = "Moderate"    // 25–30°
    case steep30     = "Steep ≥30°"  // 30–35°  (avalanche threshold start)
    case steep35     = "Steep ≥35°"  // 35–40°  (most avalanche-prone zone)
    case steep40     = "Steep ≥40°"  // 40–45°
    case extreme     = "Extreme ≥45°" // ≥45°
    case descent     = "Descent"     // any negative slope >2° down

    static func from(angleDeg: Double) -> SlopeBand {
        if angleDeg < -2 { return .descent }
        if angleDeg < 10 { return .flat }
        if angleDeg < 25 { return .gentle }
        if angleDeg < 30 { return .moderate }
        if angleDeg < 35 { return .steep30 }
        if angleDeg < 40 { return .steep35 }
        if angleDeg < 45 { return .steep40 }
        return .extreme
    }

    var colorHex: String {
        switch self {
        case .flat:      return "#22C55E"
        case .gentle:    return "#86EFAC"
        case .moderate:  return "#FBBF24"
        case .steep30:   return "#F97316" // orange — avalanche awareness begins
        case .steep35:   return "#EF4444" // red    — peak avalanche risk window
        case .steep40:   return "#B91C1C"
        case .extreme:   return "#000000"
        case .descent:   return "#06B6D4"
        }
    }
}

enum PitchAnalyzer {
    /// Analyze a polyline + elevation profile.
    /// - Parameter coords: route geometry (decoded from polyline)
    /// - Parameter elevations: parallel array of altitudes in meters; can be shorter/longer than coords (we resample)
    static func analyze(coords: [CLLocationCoordinate2D], elevations: [Int]) -> PitchAnalysis? {
        guard coords.count >= 2 else { return nil }

        // Resample elevations to match coords count via nearest-neighbor sampling.
        let elev: [Double] = (0..<coords.count).map { i in
            guard !elevations.isEmpty else { return 0 }
            let ratio = Double(i) / Double(max(1, coords.count - 1))
            let elevIdx = Int(round(ratio * Double(max(0, elevations.count - 1))))
            return Double(elevations[max(0, min(elevIdx, elevations.count - 1))])
        }

        var segments: [PitchSegment] = []
        var cumulative: Double = 0
        var totalAscent = 0.0
        var totalDescent = 0.0
        var bandDistances: [SlopeBand: Double] = [:]

        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let dist = b.distance(from: a)
            guard dist > 0.5 else { continue }

            let dz = elev[i] - elev[i - 1]
            if dz > 0 { totalAscent += dz } else { totalDescent += -dz }

            let gradientPct = (dz / dist) * 100
            let angleDeg = atan(dz / dist) * 180 / .pi
            let band = SlopeBand.from(angleDeg: angleDeg)
            bandDistances[band, default: 0] += dist
            cumulative += dist

            segments.append(PitchSegment(
                startCoord: coords[i - 1],
                endCoord: coords[i],
                startElevationM: elev[i - 1],
                endElevationM: elev[i],
                distanceM: dist,
                elevationDeltaM: dz,
                gradientPct: gradientPct,
                angleDeg: angleDeg,
                band: band,
                cumulativeDistanceM: cumulative
            ))
        }

        guard !segments.isEmpty else { return nil }

        let maxAngle = segments.map(\.angleDeg).max() ?? 0
        // Distance-weighted average for absolute angles (climbing direction)
        let totalDist = segments.reduce(0.0) { $0 + $1.distanceM }
        let weightedAngleSum = segments.reduce(0.0) { $0 + abs($1.angleDeg) * $1.distanceM }
        let avgAngle = totalDist > 0 ? weightedAngleSum / totalDist : 0

        return PitchAnalysis(
            segments: segments,
            maxAngleDeg: maxAngle,
            avgAngleDeg: avgAngle,
            totalDistanceM: totalDist,
            totalAscentM: Int(totalAscent.rounded()),
            totalDescentM: Int(totalDescent.rounded()),
            distanceInBandsM: bandDistances
        )
    }
}
