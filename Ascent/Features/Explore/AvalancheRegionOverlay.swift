import SwiftUI
import MapKit
import CoreLocation
import Combine

// Renders EAWS avalanche regions as filled MKPolygons over an Apple Map.
// Each region is colored by its current danger level (1–5, EAWS standard).
// Used inside `AvalancheRegionMapView` and as an overlay for AlpineWeatherMapView.
//
// Regions GeoJSON: https://api.avalanche.report/public/v1/regions
// Bulletins per region: https://api.avalanche.report/public/v1/bulletins/{regionId}

struct AvalancheRegion: Identifiable {
    let id: String                    // EAWS region id, e.g. "AT-07-15"
    let name: String
    let polygons: [[CLLocationCoordinate2D]] // Outer rings only (multipolygon flattened)
    var dangerLevel: Int = 0          // 0 = unknown / no bulletin
    var dangerLabel: String { AvalancheRegion.label(for: dangerLevel) }
    var color: UIColor { AvalancheRegion.color(for: dangerLevel) }

    static func color(for level: Int) -> UIColor {
        switch level {
        case 1: return UIColor(red: 0.67, green: 0.88, blue: 0.23, alpha: 1.0) // green
        case 2: return UIColor(red: 1.00, green: 0.92, blue: 0.23, alpha: 1.0) // yellow
        case 3: return UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1.0) // orange
        case 4: return UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0) // red
        case 5: return UIColor.black                                            // black
        default: return UIColor(white: 0.55, alpha: 1.0)
        }
    }
    static func label(for level: Int) -> String {
        switch level {
        case 1: return "Low"
        case 2: return "Moderate"
        case 3: return "Considerable"
        case 4: return "High"
        case 5: return "Very High"
        default: return "Unknown"
        }
    }
}

@MainActor
final class AvalancheRegionStore: ObservableObject {
    static let shared = AvalancheRegionStore()
    @Published private(set) var regions: [AvalancheRegion] = []
    @Published private(set) var isLoading = false

    private init() {}

    /// Loads region polygons + their current danger levels.
    /// Endpoint shape varies — we tolerate multiple known formats.
    func load() async {
        guard !isLoading, regions.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // 1) Pull regions GeoJSON
            let url = URL(string: "https://api.avalanche.report/public/v1/regions")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try parseGeoJSON(data: data)

            // 2) For each region, fetch its bulletin's danger level (best-effort, parallel)
            let withDangers = await withTaskGroup(of: AvalancheRegion.self) { group in
                for region in decoded.prefix(60) { // cap initial fetch to avoid hammering the API
                    group.addTask { await Self.fetchDanger(for: region) }
                }
                var out: [AvalancheRegion] = []
                for await r in group { out.append(r) }
                return out
            }

            self.regions = withDangers + decoded.dropFirst(60) // remaining stay at level 0
        } catch {
            print("⚠️ AvalancheRegionStore.load failed: \(error.localizedDescription)")
            self.regions = []
        }
    }

    private static func fetchDanger(for region: AvalancheRegion) async -> AvalancheRegion {
        guard let url = URL(string: "https://api.avalanche.report/public/v1/bulletins/\(region.id)") else { return region }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Try several shapes for the danger value
                if let ratings = json["danger_ratings"] as? [[String: Any]],
                   let level = (ratings.first?["main_value"] ?? ratings.first?["value"]) as? Int {
                    var copy = region
                    copy.dangerLevel = level
                    return copy
                }
                if let level = json["danger_level"] as? Int {
                    var copy = region
                    copy.dangerLevel = level
                    return copy
                }
            }
        } catch {
            // silent — leave at 0
        }
        return region
    }

    /// Parse GeoJSON FeatureCollection into AvalancheRegion. Tolerates Polygon and MultiPolygon.
    private func parseGeoJSON(data: Data) throws -> [AvalancheRegion] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else { return [] }

        var output: [AvalancheRegion] = []
        for feat in features {
            guard let props = feat["properties"] as? [String: Any],
                  let id = (props["id"] ?? props["region_id"]) as? String,
                  let geom = feat["geometry"] as? [String: Any],
                  let type = geom["type"] as? String else { continue }

            let name = (props["name"] ?? props["region_name"] ?? id) as? String ?? id
            var polys: [[CLLocationCoordinate2D]] = []

            switch type {
            case "Polygon":
                if let coords = geom["coordinates"] as? [[[Double]]] {
                    if let outer = coords.first {
                        polys.append(coordList(outer))
                    }
                }
            case "MultiPolygon":
                if let coords = geom["coordinates"] as? [[[[Double]]]] {
                    for poly in coords {
                        if let outer = poly.first {
                            polys.append(coordList(outer))
                        }
                    }
                }
            default:
                break
            }

            if !polys.isEmpty {
                output.append(AvalancheRegion(id: id, name: name, polygons: polys))
            }
        }
        return output
    }

    private func coordList(_ raw: [[Double]]) -> [CLLocationCoordinate2D] {
        raw.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }
}

// MARK: - SwiftUI Map view that renders the regions

struct AvalancheRegionMapView: UIViewRepresentable {
    let regions: [AvalancheRegion]
    let center: CLLocationCoordinate2D
    let span: Double

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isRotateEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        map.delegate = context.coordinator
        map.setRegion(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Refresh overlays — quick approach (re-add all). For larger lists,
        // diff would be more efficient.
        map.removeOverlays(map.overlays)
        var allPolys: [(MKPolygon, AvalancheRegion)] = []
        for region in regions {
            for ring in region.polygons {
                let poly = MKPolygon(coordinates: ring, count: ring.count)
                allPolys.append((poly, region))
            }
        }
        context.coordinator.regionByPolygon.removeAll()
        for (poly, region) in allPolys {
            context.coordinator.regionByPolygon[ObjectIdentifier(poly)] = region
            map.addOverlay(poly, level: .aboveLabels)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var regionByPolygon: [ObjectIdentifier: AvalancheRegion] = [:]

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon,
               let region = regionByPolygon[ObjectIdentifier(polygon)] {
                let r = MKPolygonRenderer(polygon: polygon)
                r.fillColor = region.color.withAlphaComponent(0.55)
                r.strokeColor = region.color.withAlphaComponent(0.85)
                r.lineWidth = 0.8
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - SwiftUI sheet — full-screen avalanche heatmap with legend

struct AvalancheHeatmapSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = AvalancheRegionStore.shared
    let center: CLLocationCoordinate2D

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                AvalancheRegionMapView(regions: store.regions, center: center, span: 6.0)
                    .ignoresSafeArea()

                if store.isLoading {
                    ProgressView("Loading bulletins…")
                        .padding(14)
                        .background(DesignSystem.Colors.surface, in: Capsule())
                        .padding(.bottom, 80)
                }

                legend
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.md)
            }
            .navigationTitle("Avalanche Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await store.load() }
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { level in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(AvalancheRegion.color(for: level)))
                        .frame(width: 11, height: 11)
                    Text("\(level)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
            }
            Spacer()
            Text("EAWS")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .tracking(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }
}
