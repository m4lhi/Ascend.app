import Foundation
import SwiftUI
import Combine
import Supabase
import CoreLocation

// =========================================
// === SUPABASE CONNECTION MANAGER ===
// =========================================

// Hier stellen wir die Verbindung zu deiner Supabase-Datenbank her.
// Diese Variable ist global, damit die ganze App darauf zugreifen kann.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qujkzrwrhrqejsqulohy.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1amt6cndyaHJxZWpzcXVsb2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTQzMDYsImV4cCI6MjA4ODU3MDMwNn0.mdB8rjht5QtGcYmeEbNmYDlXLdsHcH9jzxmTOi4S28E"
)

// --- POI Model ---
// Definiert interessante Orte auf der Karte (Hütten, Aussichtspunkte etc.)
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
// Generierte Routen, die in der ExploreView vorgeschlagen werden
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
    // Diese Listen versorgen deine Karte und UI mit Daten
    @Published var mountains: [Mountain] = []
    @Published var nearbyMountains: [Mountain] = []
    @Published var nearbyPOIs: [PointOfInterest] = []
    @Published var nearbyRoutes: [NearbyRoute] = []
    @Published var savedRoutes: [SavedRoute] = []

    // Lädt initial die 100 höchsten Prestige Peaks (als Start-Daten)
    func fetchMountainsFromDatabase() async {
        do {
            let fetched: [Mountain] = try await supabase
                .from("mountains")
                .select()
                .order("elevation", ascending: false)
                .limit(100)
                .execute()
                .value
            
            // Client-seitiges Sortieren: Prestige Peaks zuerst, dann nach Höhe
            self.mountains = fetched.sorted {
                if $0.isPrestigePeak != $1.isPrestigePeak { return $0.isPrestigePeak }
                return $0.elevation > $1.elevation
            }
            print("✅ fetchMountainsFromDatabase returned \(mountains.count) mountains")
        } catch {
            print("❌ Error fetching mountains from Supabase: \(error)")
        }
    }

    // === ANTI-LAG Bounding Box Query ===
    // Lade nur die Berge, die im aktuellen Kartenausschnitt sichtbar sind.
    func fetchMountainsInBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, zoomLevel: ExploreView.ZoomLevel) async {
        do {
            // Definiert den Bereich der Karte, der gerade sichtbar ist
            let baseQuery = supabase.from("mountains")
                .select()
                .gte("latitude", value: minLat)
                .lte("latitude", value: maxLat)
                .gte("longitude", value: minLon)
                .lte("longitude", value: maxLon)
            
            let visiblePeaks: [Mountain]
            
            // Je nach Zoom-Level laden wir mehr oder weniger Berge, um die Karte flüssig zu halten
            if zoomLevel == .far {
                visiblePeaks = try await baseQuery.eq("isPrestigePeak", value: true).limit(40).execute().value
            } else if zoomLevel == .medium {
                visiblePeaks = try await baseQuery.limit(100).execute().value
            } else {
                visiblePeaks = try await baseQuery.limit(250).execute().value
            }
            
            // Aktualisiere die UI mit den neuen Bergen
            await MainActor.run {
                self.mountains = visiblePeaks
            }
        } catch {
            print("❌ Fehler beim Laden der Bounding Box: \(error)")
        }
    }

    // Server-side search by name/region
    // Löst den Supabase-Typfehler (PostgrestTransformBuilder), indem wir die Abfragen trennen
    func searchMountains(query: String, difficulty: Difficulty?) async {
        do {
            let results: [Mountain]
            
            // Fall 1: User sucht nach Text UND Schwierigkeit
            if !query.isEmpty && difficulty != nil {
                results = try await supabase.from("mountains").select()
                    .or("name.ilike.%\(query)%,region.ilike.%\(query)%")
                    .eq("difficulty", value: difficulty!.rawValue)
                    .execute().value
                
            // Fall 2: User sucht NUR nach Text
            } else if !query.isEmpty {
                results = try await supabase.from("mountains").select()
                    .or("name.ilike.%\(query)%,region.ilike.%\(query)%")
                    .execute().value
                
            // Fall 3: User sucht NUR nach Schwierigkeit
            } else if let diff = difficulty {
                results = try await supabase.from("mountains").select()
                    .eq("difficulty", value: diff.rawValue)
                    .execute().value
                
            // Fall 4: Weder noch (lade einfach die Standard-Liste)
            } else {
                results = try await supabase.from("mountains").select()
                    .limit(100)
                    .execute().value
            }
            
            self.mountains = results
        } catch {
            print("❌ Search error: \(error)")
        }
    }

    // PostGIS nearby query (Lädt Berge im Umkreis der User-Location)
    func fetchNearbyMountains(latitude: Double, longitude: Double, radiusKm: Double = 25) async {
        do {
            let results: [Mountain] = try await supabase
                .rpc("nearby_mountains", params: ["lat": latitude, "lon": longitude, "radius_km": radiusKm])
                .execute()
                .value
            self.nearbyMountains = results
            print("📍 Nearby: \(results.count) mountains within \(Int(radiusKm))km")
            
            // Erstellt automatisch zusammenhängende Routen aus nah beieinanderliegenden Bergen
            generateNearbyRoutes(from: results)
        } catch {
            print("❌ Nearby mountains error (is PostGIS enabled?): \(error)")
        }
    }

    // PostGIS nearby POI query (Points of Interest um den User herum)
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

    // Lade Top 10 Mountains für die Suchvorschläge in der ExploreView
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

    // Setzt die Umkreis-Suche und Routen zurück
    func clearNearby() {
        nearbyMountains = []
        nearbyPOIs = []
        nearbyRoutes = []
    }

    // MARK: - Route Generation (from nearby mountain clusters within 5km)

    // Baut automatisch Routen zusammen, wenn Berge näher als 5km beieinander liegen
    func generateNearbyRoutes(from mountains: [Mountain]) {
        let validMountains = mountains.filter { $0.latitude != nil && $0.longitude != nil }
        guard validMountains.count >= 2 else {
            nearbyRoutes = []
            return
        }

        var used = Set<UUID>()
        var routes: [NearbyRoute] = []

        for mountain in validMountains {
            // Überspringe Berge, die schon in einer Route sind
            guard !used.contains(mountain.id) else { continue }

            // Finde Berge im Umkreis von 5km
            let cluster = validMountains.filter { other in
                guard other.id != mountain.id, !used.contains(other.id) else { return false }
                let dist = distanceBetween(
                    lat1: mountain.latitude!, lon1: mountain.longitude!,
                    lat2: other.latitude!, lon2: other.longitude!
                )
                return dist <= 5.0
            }

            // Wenn keine Berge in der Nähe sind, überspringen
            guard !cluster.isEmpty else { continue }

            // Füge sie zusammen und sortiere nach Breitengrad für einen logischen Weg
            var routeMountains = [mountain] + cluster
            routeMountains.sort { ($0.latitude ?? 0) < ($1.latitude ?? 0) }

            // Markiere diese Berge als verwendet
            for m in routeMountains { used.insert(m.id) }

            // Berechne Distanz, Höhenmeter und Schwierigkeit der Route
            var totalDist = 0.0
            for i in 0..<(routeMountains.count - 1) {
                totalDist += distanceBetween(
                    lat1: routeMountains[i].latitude!, lon1: routeMountains[i].longitude!,
                    lat2: routeMountains[i+1].latitude!, lon2: routeMountains[i+1].longitude!
                )
            }
            let totalElevation = routeMountains.reduce(0) { $0 + $1.elevation / 10 }
            let hardest = routeMountains.map { $0.difficulty }.max(by: { difficultyRank($0) < difficultyRank($1) }) ?? .medium
            
            // Angenommene Gehgeschwindigkeit: 3.5 km/h
            let durationMinutes = Int((totalDist / 3.5) * 60)

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

    // Speichert eine vom User erstellte Route in der Datenbank
    func saveRoute(_ route: SavedRoute) async {
        do {
            try await supabase.from("saved_routes").insert(route).execute()
            print("✅ Route saved: \(route.name)")
            await fetchSavedRoutes() // Lade die Liste neu, um die UI zu aktualisieren
        } catch {
            print("❌ Save route error: \(error)")
        }
    }

    // Lädt alle vom User gespeicherten Routen aus der Datenbank
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

    // Löscht eine Route aus der Datenbank
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

    // Berechnet die Distanz zwischen zwei Koordinaten in Kilometern
    private func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let loc1 = CLLocation(latitude: lat1, longitude: lon1)
        let loc2 = CLLocation(latitude: lat2, longitude: lon2)
        return loc1.distance(from: loc2) / 1000.0
    }

    // Hilfsfunktion, um den schwierigsten Berg einer Route zu ermitteln
    private func difficultyRank(_ d: Difficulty) -> Int {
        switch d {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .extreme: return 3
        case .expert: return 4 // Enthält jetzt auch 'Expert'
        }
    }
}
