import Foundation
import SwiftUI
import Combine
import Supabase
import CoreLocation

// =========================================
// === SUPABASE CONNECTION MANAGER ===
// =========================================

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qujkzrwrhrqejsqulohy.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1amt6cndyaHJxZWpzcXVsb2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTQzMDYsImV4cCI6MjA4ODU3MDMwNn0.mdB8rjht5QtGcYmeEbNmYDlXLdsHcH9jzxmTOi4S28E"
)

// --- POI Model ---
struct PointOfInterest: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: String         // "viewpoint", "summit", "hut", "water"
    let latitude: Double
    let longitude: Double
    let elevation: Int?
    let description: String?
}

// --- Nearby Route (generated from mountain clusters) ---
struct NearbyRoute: Identifiable {
    let id = UUID()
    let name: String
    let mountains: [Mountain]
    let totalDistanceKm: Double
    let totalElevationGain: Int
    let difficulty: Difficulty
    let estimatedDurationMinutes: Int

    var peakCount: Int { mountains.count }
}

@MainActor
class MountainManager: ObservableObject {
    @Published var mountains: [Mountain] = []
    @Published var nearbyMountains: [Mountain] = []
    @Published var nearbyPOIs: [PointOfInterest] = []
    @Published var nearbyRoutes: [NearbyRoute] = []
    @Published var savedRoutes: [SavedRoute] = []

    // Loads mountains ordered by prestige and elevation
    func fetchMountainsFromDatabase() async {
        do {
            let fetched: [Mountain] = try await supabase
                .from("mountains")
                .select()
                .order("elevation", ascending: false)
                .limit(100)
                .execute()
                .value
            // Client-side sort: prestige peaks first, then by elevation
            self.mountains = fetched.sorted {
                if $0.isPrestigePeak != $1.isPrestigePeak { return $0.isPrestigePeak }
                return $0.elevation > $1.elevation
            }
            // Debug: verify data is actually returned
            print("✅ fetchMountainsFromDatabase returned \(mountains.count) mountains")
            if mountains.isEmpty {
                print("⚠️ Mountains array is EMPTY — check CodingKeys match Supabase columns!")
            } else {
                let first = mountains[0]
                print("   First: \(first.name) (\(first.elevation)m) prestige=\(first.isPrestigePeak) lat=\(first.latitude ?? 0) lon=\(first.longitude ?? 0)")
            }
        } catch {
            print("❌ Error fetching mountains from Supabase: \(error)")
            print("   Check that CodingKeys in Mountain struct match exact Supabase column names")
        }
    }

    // Server-side search by name/region
    func searchMountains(query: String, difficulty: Difficulty?) async {
        do {
            var queryBuilder = supabase.from("mountains").select()
            if !query.isEmpty {
                queryBuilder = queryBuilder.or("name.ilike.%\(query)%,region.ilike.%\(query)%")
            }
            if let difficulty {
                queryBuilder = queryBuilder.eq("difficulty", value: difficulty.rawValue)
            }
            let results: [Mountain] = try await queryBuilder.execute().value
            self.mountains = results
        } catch {
            print("❌ Search error: \(error)")
        }
    }

    // PostGIS nearby query
    func fetchNearbyMountains(latitude: Double, longitude: Double, radiusKm: Double = 25) async {
        do {
            let results: [Mountain] = try await supabase
                .rpc("nearby_mountains", params: ["lat": latitude, "lon": longitude, "radius_km": radiusKm])
                .execute()
                .value
            self.nearbyMountains = results
            print("📍 Nearby: \(results.count) mountains within \(Int(radiusKm))km")
            // Generate routes from nearby mountain clusters
            generateNearbyRoutes(from: results)
        } catch {
            print("❌ Nearby mountains error (is PostGIS enabled?): \(error)")
        }
    }

    // PostGIS nearby POI query
    func fetchNearbyPOIs(latitude: Double, longitude: Double, radiusKm: Double = 25) async {
        do {
            let results: [PointOfInterest] = try await supabase
                .rpc("nearby_pois", params: ["lat": latitude, "lon": longitude, "radius_km": radiusKm])
                .execute()
                .value
            self.nearbyPOIs = results
        } catch {
            print("❌ Nearby POIs error: \(error)")
        }
    }

    // Top 10 mountains for search suggestions
    func fetchTopMountains() async {
        do {
            let results: [Mountain] = try await supabase
                .from("mountains")
                .select()
                .order("isPrestigePeak", ascending: false)
                .order("elevation", ascending: false)
                .limit(10)
                .execute()
                .value
            self.mountains = results
        } catch {
            print("❌ Top mountains error: \(error)")
        }
    }

    func clearNearby() {
        nearbyMountains = []
        nearbyPOIs = []
        nearbyRoutes = []
    }

    // MARK: - Route Generation (from nearby mountain clusters within 5km)

    func generateNearbyRoutes(from mountains: [Mountain]) {
        let validMountains = mountains.filter { $0.latitude != nil && $0.longitude != nil }
        guard validMountains.count >= 2 else {
            nearbyRoutes = []
            return
        }

        var used = Set<UUID>()
        var routes: [NearbyRoute] = []

        for mountain in validMountains {
            guard !used.contains(mountain.id) else { continue }

            let cluster = validMountains.filter { other in
                guard other.id != mountain.id, !used.contains(other.id) else { return false }
                let dist = distanceBetween(
                    lat1: mountain.latitude!, lon1: mountain.longitude!,
                    lat2: other.latitude!, lon2: other.longitude!
                )
                return dist <= 5.0 // 5km radius cluster
            }

            guard !cluster.isEmpty else { continue }

            var routeMountains = [mountain] + cluster
            // Sort by latitude for a logical path
            routeMountains.sort { ($0.latitude ?? 0) < ($1.latitude ?? 0) }

            // Mark as used
            for m in routeMountains { used.insert(m.id) }

            // Calculate route stats
            var totalDist = 0.0
            for i in 0..<(routeMountains.count - 1) {
                totalDist += distanceBetween(
                    lat1: routeMountains[i].latitude!, lon1: routeMountains[i].longitude!,
                    lat2: routeMountains[i+1].latitude!, lon2: routeMountains[i+1].longitude!
                )
            }
            let totalElevation = routeMountains.reduce(0) { $0 + $1.elevation / 10 }
            let hardest = routeMountains.map { $0.difficulty }.max(by: { difficultyRank($0) < difficultyRank($1) }) ?? .medium
            let durationMinutes = Int((totalDist / 3.5) * 60) // 3.5 km/h avg hiking speed

            let routeName: String
            if routeMountains.count == 2 {
                routeName = "\(routeMountains[0].name) – \(routeMountains[1].name)"
            } else {
                routeName = "\(routeMountains[0].region) Alpine Trail"
            }

            routes.append(NearbyRoute(
                name: routeName,
                mountains: routeMountains,
                totalDistanceKm: totalDist,
                totalElevationGain: totalElevation,
                difficulty: hardest,
                estimatedDurationMinutes: max(durationMinutes, 30)
            ))
        }

        nearbyRoutes = routes
        print("🥾 Generated \(routes.count) nearby routes from \(validMountains.count) mountains")
    }

    // MARK: - Saved Routes (Supabase CRUD)

    func saveRoute(_ route: SavedRoute) async {
        do {
            try await supabase.from("saved_routes").insert(route).execute()
            print("✅ Route saved: \(route.name)")
            await fetchSavedRoutes()
        } catch {
            print("❌ Save route error: \(error)")
        }
    }

    func fetchSavedRoutes() async {
        do {
            let userId = try await supabase.auth.session.user.id
            let results: [SavedRoute] = try await supabase
                .from("saved_routes")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            self.savedRoutes = results
            print("📋 Loaded \(results.count) saved routes")
        } catch {
            print("❌ Fetch saved routes error: \(error)")
        }
    }

    func deleteRoute(id: UUID) async {
        do {
            try await supabase.from("saved_routes").delete().eq("id", value: id).execute()
            savedRoutes.removeAll { $0.id == id }
            print("🗑️ Route deleted")
        } catch {
            print("❌ Delete route error: \(error)")
        }
    }

    // MARK: - Helpers

    private func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let loc1 = CLLocation(latitude: lat1, longitude: lon1)
        let loc2 = CLLocation(latitude: lat2, longitude: lon2)
        return loc1.distance(from: loc2) / 1000.0 // km
    }

    private func difficultyRank(_ d: Difficulty) -> Int {
        switch d {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .extreme: return 3
        }
    }
}

// =========================================
// === SUPABASE SCHEMA REQUIREMENTS ===
// =========================================
//
// 1. Enable PostGIS:
//    CREATE EXTENSION IF NOT EXISTS postgis;
//
// 2. RPC for nearby mountains:
//    CREATE OR REPLACE FUNCTION nearby_mountains(
//        lat double precision, lon double precision, radius_km double precision DEFAULT 25
//    ) RETURNS SETOF mountains AS $$
//      SELECT * FROM mountains
//      WHERE latitude IS NOT NULL AND longitude IS NOT NULL
//        AND ST_DWithin(
//            ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//            ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
//            radius_km * 1000)
//      ORDER BY ST_Distance(
//        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography);
//    $$ LANGUAGE sql;
//
// 3. POI table:
//    CREATE TABLE points_of_interest (
//        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
//        name TEXT NOT NULL, type TEXT NOT NULL,
//        latitude DOUBLE PRECISION NOT NULL, longitude DOUBLE PRECISION NOT NULL,
//        elevation INT, description TEXT);
//
// 4. RPC for nearby POIs:
//    CREATE OR REPLACE FUNCTION nearby_pois(
//        lat double precision, lon double precision, radius_km double precision DEFAULT 25
//    ) RETURNS SETOF points_of_interest AS $$
//      SELECT * FROM points_of_interest
//      WHERE ST_DWithin(
//          ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//          ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
//          radius_km * 1000)
//      ORDER BY ST_Distance(
//        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography);
//    $$ LANGUAGE sql;
//
// 5. Saved routes table:
//    CREATE TABLE saved_routes (
//        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
//        user_id UUID REFERENCES auth.users(id),
//        name TEXT NOT NULL,
//        mountain_ids UUID[] NOT NULL,
//        created_at TIMESTAMPTZ DEFAULT now(),
//        total_distance_km DOUBLE PRECISION,
//        total_elevation_gain INT,
//        estimated_duration_minutes INT,
//        difficulty TEXT);
