import Foundation
import CoreLocation

// Avalanche danger from EAWS (European Avalanche Warning Services).
// Multi-region open API — covers CH, AT, DE, IT, FR, SI, etc.
//
// Public docs: https://www.avalanches.org/eaws/
// Bulletins endpoint: https://api.avalanche.report/public/v1/bulletins/{region}
//
// EAWS Danger scale (1–5):
//   1 = Low, 2 = Moderate, 3 = Considerable, 4 = High, 5 = Very High
struct AvalancheBulletin: Codable, Identifiable {
    let id: String
    let regionId: String
    let regionName: String
    let validFrom: String
    let validUntil: String
    let dangerLevel: Int          // 1–5 highest danger across elevations
    let dangerLevelAbove: Int?    // above tree line
    let dangerLevelBelow: Int?
    let elevationThresholdM: Int?
    let problems: [String]        // e.g. "wind_slab", "new_snow", "wet_snow"
    let summaryEN: String
    let summaryDE: String?
}

extension AvalancheBulletin {
    var dangerLabel: String {
        switch dangerLevel {
        case 1: return "Low"
        case 2: return "Moderate"
        case 3: return "Considerable"
        case 4: return "High"
        case 5: return "Very High"
        default: return "Unknown"
        }
    }

    var dangerColorHex: String {
        switch dangerLevel {
        case 1: return "#ABE03A" // green
        case 2: return "#FFEB3B" // yellow
        case 3: return "#FF9800" // orange
        case 4: return "#F44336" // red
        case 5: return "#000000" // black
        default: return "#9E9E9E"
        }
    }
}

@MainActor
final class AvalancheService {
    static let shared = AvalancheService()
    private init() {}

    /// Picks the best regional bulletin source for the given coordinate.
    /// Switzerland uses SLF (more accurate for CH), other Alpine regions use EAWS.
    func fetchBulletin(for coord: CLLocationCoordinate2D) async throws -> AvalancheBulletin? {
        // Switzerland approx bounding box → SLF
        if (45.7...47.85).contains(coord.latitude) && (5.95...10.5).contains(coord.longitude) {
            if let slf = try? await fetchSLF(coord: coord) { return slf }
        }
        // Default: EAWS (covers AT, IT South Tyrol, FR, SI etc.)
        return try await fetchEAWS(coord: coord)
    }

    // MARK: - EAWS (European)

    private func fetchEAWS(coord: CLLocationCoordinate2D) async throws -> AvalancheBulletin? {
        // Region resolver: ask EAWS which region a lat/lon belongs to
        let url = URL(string: "https://api.avalanche.report/public/v1/regions?lat=\(coord.latitude)&lon=\(coord.longitude)")!
        let (regionData, _) = try await URLSession.shared.data(from: url)
        guard let regionResp = try? JSONDecoder().decode(EAWSRegionLookup.self, from: regionData),
              let regionId = regionResp.regionId else { return nil }

        let bulletinURL = URL(string: "https://api.avalanche.report/public/v1/bulletins/\(regionId)")!
        let (bData, _) = try await URLSession.shared.data(from: bulletinURL)
        guard let raw = try? JSONDecoder().decode(EAWSBulletinWire.self, from: bData) else { return nil }

        return AvalancheBulletin(
            id: raw.bulletinID ?? UUID().uuidString,
            regionId: regionId,
            regionName: raw.regionName ?? regionId,
            validFrom: raw.validity?.from ?? "",
            validUntil: raw.validity?.to ?? "",
            dangerLevel: raw.dangerRatings?.first?.mainValue ?? 0,
            dangerLevelAbove: raw.dangerRatings?.first?.aboveValue,
            dangerLevelBelow: raw.dangerRatings?.first?.belowValue,
            elevationThresholdM: raw.dangerRatings?.first?.elevationLowerBound,
            problems: raw.avalancheProblems?.compactMap { $0.problemType } ?? [],
            summaryEN: raw.avalancheActivity?.highlightsEN ?? raw.avalancheActivity?.commentEN ?? "",
            summaryDE: raw.avalancheActivity?.highlightsDE ?? raw.avalancheActivity?.commentDE
        )
    }

    // MARK: - SLF (Swiss Avalanche Bulletin)

    private func fetchSLF(coord: CLLocationCoordinate2D) async throws -> AvalancheBulletin? {
        // SLF GeoJSON-style endpoint
        let url = URL(string: "https://www.slf.ch/avalanche/api/gateway/maps/v2/geojson/danger/regions")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let regions = try? JSONDecoder().decode(SLFRegionsResponse.self, from: data) else { return nil }

        // Find region whose bounding box contains the coord (rough match)
        guard let region = regions.features.first(where: { feat in
            feat.containsPoint(lat: coord.latitude, lon: coord.longitude)
        }) else { return nil }

        return AvalancheBulletin(
            id: region.properties.regionId ?? UUID().uuidString,
            regionId: region.properties.regionId ?? "ch",
            regionName: region.properties.regionName ?? "Switzerland",
            validFrom: region.properties.validFrom ?? "",
            validUntil: region.properties.validUntil ?? "",
            dangerLevel: region.properties.dangerLevel ?? 0,
            dangerLevelAbove: region.properties.dangerLevel,
            dangerLevelBelow: region.properties.dangerLevel,
            elevationThresholdM: nil,
            problems: [],
            summaryEN: region.properties.summary ?? "",
            summaryDE: region.properties.summary
        )
    }
}

// MARK: - EAWS wire format

private struct EAWSRegionLookup: Codable {
    let regionId: String?

    enum CodingKeys: String, CodingKey {
        case regionId = "region_id"
    }
}

private struct EAWSBulletinWire: Codable {
    let bulletinID: String?
    let regionName: String?
    let validity: Validity?
    let dangerRatings: [DangerRating]?
    let avalancheProblems: [Problem]?
    let avalancheActivity: Activity?

    enum CodingKeys: String, CodingKey {
        case bulletinID        = "bulletin_id"
        case regionName        = "region_name"
        case validity
        case dangerRatings     = "danger_ratings"
        case avalancheProblems = "avalanche_problems"
        case avalancheActivity = "avalanche_activity"
    }

    struct Validity: Codable {
        let from: String?
        let to: String?
    }
    struct DangerRating: Codable {
        let mainValue: Int?
        let aboveValue: Int?
        let belowValue: Int?
        let elevationLowerBound: Int?

        enum CodingKeys: String, CodingKey {
            case mainValue           = "main_value"
            case aboveValue          = "above_value"
            case belowValue          = "below_value"
            case elevationLowerBound = "elevation_lower_bound"
        }
    }
    struct Problem: Codable {
        let problemType: String?

        enum CodingKeys: String, CodingKey {
            case problemType = "problem_type"
        }
    }
    struct Activity: Codable {
        let highlightsEN: String?
        let highlightsDE: String?
        let commentEN: String?
        let commentDE: String?

        enum CodingKeys: String, CodingKey {
            case highlightsEN = "highlights_en"
            case highlightsDE = "highlights_de"
            case commentEN    = "comment_en"
            case commentDE    = "comment_de"
        }
    }
}

// MARK: - SLF wire format

private struct SLFRegionsResponse: Codable {
    let features: [Feature]

    struct Feature: Codable {
        let geometry: Geometry?
        let properties: Properties

        struct Geometry: Codable {
            let type: String?
            let coordinates: [[[Double]]]? // polygons (2-deep)
        }
        struct Properties: Codable {
            let regionId: String?
            let regionName: String?
            let dangerLevel: Int?
            let validFrom: String?
            let validUntil: String?
            let summary: String?

            enum CodingKeys: String, CodingKey {
                case regionId    = "region_id"
                case regionName  = "region_name"
                case dangerLevel = "danger_rating"
                case validFrom   = "valid_from"
                case validUntil  = "valid_until"
                case summary     = "comment"
            }
        }

        // Rough point-in-polygon for the (often complex) SLF region polygons.
        func containsPoint(lat: Double, lon: Double) -> Bool {
            guard let polys = geometry?.coordinates else { return false }
            for ring in polys {
                if ringContains(ring: ring, lat: lat, lon: lon) { return true }
            }
            return false
        }

        private func ringContains(ring: [[Double]], lat: Double, lon: Double) -> Bool {
            var inside = false
            var j = ring.count - 1
            for i in 0..<ring.count {
                let xi = ring[i][0], yi = ring[i][1]
                let xj = ring[j][0], yj = ring[j][1]
                let intersect = ((yi > lat) != (yj > lat)) &&
                    (lon < (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 0.0001 : (yj - yi)) + xi)
                if intersect { inside = !inside }
                j = i
            }
            return inside
        }
    }
}
