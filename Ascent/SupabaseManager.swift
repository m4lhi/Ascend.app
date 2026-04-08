import Foundation
import SwiftUI
import Combine
import Supabase
import CoreLocation

// =========================================
// === SUPABASE CONNECTION MANAGER ===
// =========================================

let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? ""
let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""

let supabase = SupabaseClient(
    supabaseURL: URL(string: supabaseURL)!,
    supabaseKey: supabaseKey,
    options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
)

struct PointOfInterest: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: String
    let latitude: Double
    let longitude: Double
    let elevation: Int?
    let description: String?
}

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

    func fetchMountainsFromDatabase() async {
        // Wird dynamisch über fetchMountainsInBounds geladen
    }

    // === ANTI-LAG & LEVEL OF DETAIL Query ===
        func fetchMountainsInBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, zoomLevel: ExploreView.ZoomLevel) async {
            do {
                let baseQuery = supabase.from("mountains")
                    .select("*, routes:mountain_routes(*)")
                    .gte("latitude", value: minLat)
                    .lte("latitude", value: maxLat)
                    .gte("longitude", value: minLon)
                    .lte("longitude", value: maxLon)
                
                let visiblePeaks: [Mountain]

                if zoomLevel == .far {
                    // 1. Lade eine größere Auswahl (100 Berge) — nur Kartenfelder
                    let rawPeaks: [Mountain] = try await baseQuery
                        .order("isPrestigePeak", ascending: false)
                        .order("elevation", ascending: false)
                        .limit(100)
                        .execute().value
                    
                    // 2. 🟢 REGIONAL-FILTER: Behalte nur EINEN Berg pro Region!
                    var seenRegions = Set<String>()
                    visiblePeaks = rawPeaks.filter { peak in
                        // Manche Berge haben evtl. leere Region-Strings, behandle diese als "Unknown"
                        let regionName = peak.region.isEmpty ? "Unknown" : peak.region
                        
                        if seenRegions.contains(regionName) {
                            return false // Wir haben schon ein Highlight für diese Region -> Überspringen
                        } else {
                            seenRegions.insert(regionName)
                            return true // Das ist der höchste Berg dieser Region -> Behalten
                        }
                    }
                    // 3. Schneide die Liste am Ende auf 15 geografisch verteilte Highlights ab
                    .prefix(15).map { $0 }
                    
                } else if zoomLevel == .medium {
                    // REGION-ANSICHT: Zeigt die wichtigsten ~60 Berge einer Region
                    visiblePeaks = try await baseQuery
                        .order("isPrestigePeak", ascending: false)
                        .order("elevation", ascending: false)
                        .limit(60)
                        .execute().value
                } else {
                    // DETAIL-ANSICHT (Nah): Zeigt alle Berge im Umkreis (bis zu 500)
                    visiblePeaks = try await baseQuery
                        .order("elevation", ascending: false)
                        .limit(500)
                        .execute().value
                }
                
                await MainActor.run {
                    var currentSet = Set(self.mountains)
                    currentSet.formUnion(visiblePeaks)
                    self.mountains = Array(currentSet)
                }
            } catch {
                print("❌ Fehler beim Laden der Bounding Box: \(error)")
            }
        }

    func searchMountains(query: String, difficulty: Difficulty?) async {
        do {
            // Sanitize input: strip PostgREST special characters to prevent filter injection
            let safe = query
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "\\", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let results: [Mountain]
            if !safe.isEmpty, let diff = difficulty {
                results = try await supabase.from("mountains").select("*, routes:mountain_routes(*)")
                    .or("name.ilike.%\(safe)%,region.ilike.%\(safe)%,country.ilike.%\(safe)%")
                    .eq("difficulty", value: diff.rawValue)
                    .execute().value
            } else if !safe.isEmpty {
                results = try await supabase.from("mountains").select("*, routes:mountain_routes(*)")
                    .or("name.ilike.%\(safe)%,region.ilike.%\(safe)%,country.ilike.%\(safe)%")
                    .execute().value
            } else if let diff = difficulty {
                results = try await supabase.from("mountains").select("*, routes:mountain_routes(*)")
                    .eq("difficulty", value: diff.rawValue)
                    .execute().value
            } else {
                results = try await supabase.from("mountains").select("*, routes:mountain_routes(*)")
                    .limit(100)
                    .execute().value
            }
            self.mountains = results
        } catch {
            print("❌ Search error: \(error)")
        }
    }

    func fetchNearbyMountains(latitude: Double, longitude: Double, radiusKm: Double = 25) async {
        do {
            let results: [Mountain] = try await supabase
                .rpc("nearby_mountains", params: ["lat": latitude, "lon": longitude, "radius_km": radiusKm])
                .execute()
                .value
            self.nearbyMountains = results
        } catch {
            print("❌ Nearby mountains error: \(error)")
        }
    }

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

    func fetchTopMountains() async {
        do {
            let results: [Mountain] = try await supabase
                .from("mountains")
                .select("*, routes:mountain_routes(*)")
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

    func saveRoute(_ route: SavedRoute) async {
        do {
            try await supabase.from("saved_routes").insert(route).execute()
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
        } catch {
            print("❌ Fetch saved routes error: \(error)")
        }
    }

    func deleteRoute(id: UUID) async {
        do {
            try await supabase.from("saved_routes").delete().eq("id", value: id).execute()
            savedRoutes.removeAll { $0.id == id }
        } catch {
            print("❌ Delete route error: \(error)")
        }
    }
}
