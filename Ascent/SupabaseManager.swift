import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === SUPABASE CONNECTION MANAGER ===
// =========================================

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qujkzrwrhrqejsqulohy.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1amt6cndyaHJxZWpzcXVsb2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTQzMDYsImV4cCI6MjA4ODU3MDMwNn0.mdB8rjht5QtGcYmeEbNmYDlXLdsHcH9jzxmTOi4S28E"
)

// --- POI Model ---
// Requires `points_of_interest` table in Supabase (see schema notes at bottom)
struct PointOfInterest: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: String         // "viewpoint", "summit", "hut", "water"
    let latitude: Double
    let longitude: Double
    let elevation: Int?
    let description: String?
}

@MainActor
class MountainManager: ObservableObject {
    @Published var mountains: [Mountain] = []
    @Published var nearbyMountains: [Mountain] = []
    @Published var nearbyPOIs: [PointOfInterest] = []

    // Loads mountains ordered by prestige and elevation (limit 200)
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
            print("✅ Successfully loaded \(mountains.count) mountains from Supabase!")
        } catch {
            print("❌ Error fetching mountains from Supabase: \(error)")
        }
    }

    // Server-side search by name/region (ILIKE) and optional difficulty filter.
    // All queries are async and non-blocking.
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

    // PostGIS nearby query — requires `nearby_mountains` RPC function in Supabase.
    // Uses ST_DWithin for radius-based spatial filtering.
    func fetchNearbyMountains(latitude: Double, longitude: Double, radiusKm: Double = 25) async {
        do {
            let results: [Mountain] = try await supabase
                .rpc("nearby_mountains", params: ["lat": latitude, "lon": longitude, "radius_km": radiusKm])
                .execute()
                .value
            self.nearbyMountains = results
        } catch {
            print("❌ Nearby mountains error (is PostGIS enabled?): \(error)")
        }
    }

    // PostGIS nearby POI query — requires `nearby_pois` RPC and `points_of_interest` table.
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

    // Top 10 mountains for search suggestions (prestige first, then by elevation)
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
    }
}

// =========================================
// === SUPABASE SCHEMA REQUIREMENTS ===
// =========================================
//
// 1. Enable PostGIS:
//    CREATE EXTENSION IF NOT EXISTS postgis;
//
// 2. RPC for nearby mountains (uses existing lat/lon columns):
//    CREATE OR REPLACE FUNCTION nearby_mountains(
//        lat double precision,
//        lon double precision,
//        radius_km double precision DEFAULT 25
//    ) RETURNS SETOF mountains AS $$
//      SELECT *
//      FROM mountains
//      WHERE latitude IS NOT NULL AND longitude IS NOT NULL
//        AND ST_DWithin(
//            ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//            ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
//            radius_km * 1000
//        )
//      ORDER BY ST_Distance(
//        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
//      );
//    $$ LANGUAGE sql;
//
// 3. New table for points of interest:
//    CREATE TABLE points_of_interest (
//        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
//        name TEXT NOT NULL,
//        type TEXT NOT NULL,  -- 'viewpoint', 'summit', 'hut', 'water'
//        latitude DOUBLE PRECISION NOT NULL,
//        longitude DOUBLE PRECISION NOT NULL,
//        elevation INT,
//        description TEXT
//    );
//
// 4. RPC for nearby POIs:
//    CREATE OR REPLACE FUNCTION nearby_pois(
//        lat double precision,
//        lon double precision,
//        radius_km double precision DEFAULT 25
//    ) RETURNS SETOF points_of_interest AS $$
//      SELECT *
//      FROM points_of_interest
//      WHERE ST_DWithin(
//          ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//          ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
//          radius_km * 1000
//      )
//      ORDER BY ST_Distance(
//        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
//        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
//      );
//    $$ LANGUAGE sql;
