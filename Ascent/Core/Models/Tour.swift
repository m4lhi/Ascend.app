import Foundation
import CoreLocation

// =========================================
// === DATEI: Tour.swift ===
// === Tour-domain data models ===
// =========================================
//
// Pure data models for tours and their social interactions
// (fist bumps, comments, bookmarks). Extracted from AppState in R3
// so FeedService / FeedViewModel can depend on the models without
// transitively pulling in AppState.

// MARK: - Tour wire format (Supabase `tours` table row)

struct CloudTour: Codable {
    let id: UUID?
    let user_id: UUID
    let name: String
    let elevation: Int
    let date: Date
    let difficulty: String
    let notes: String
    let duration_seconds: Int?
    let distance_km: Double?
    let pauses: String?
    let photo_url: String?
    let route_polyline: String?  // Encoded route coordinates for map display

    // Custom decoder: gracefully handle missing route_polyline column in DB
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        name = try c.decode(String.self, forKey: .name)
        elevation = try c.decode(Int.self, forKey: .elevation)
        date = try c.decode(Date.self, forKey: .date)
        difficulty = try c.decode(String.self, forKey: .difficulty)
        notes = try c.decode(String.self, forKey: .notes)
        duration_seconds = try c.decodeIfPresent(Int.self, forKey: .duration_seconds)
        distance_km = try c.decodeIfPresent(Double.self, forKey: .distance_km)
        pauses = try c.decodeIfPresent(String.self, forKey: .pauses)
        photo_url = try c.decodeIfPresent(String.self, forKey: .photo_url)
        route_polyline = try c.decodeIfPresent(String.self, forKey: .route_polyline)
    }

    // Keep regular init for creating new tours
    init(id: UUID?, user_id: UUID, name: String, elevation: Int, date: Date, difficulty: String, notes: String, duration_seconds: Int?, distance_km: Double?, pauses: String?, photo_url: String?, route_polyline: String?) {
        self.id = id; self.user_id = user_id; self.name = name; self.elevation = elevation
        self.date = date; self.difficulty = difficulty; self.notes = notes
        self.duration_seconds = duration_seconds; self.distance_km = distance_km
        self.pauses = pauses; self.photo_url = photo_url; self.route_polyline = route_polyline
    }
}

// MARK: - Tour UI model (denormalized for display + interactions)

struct Tour: Identifiable {
    let id = UUID()
    let cloudId: UUID?
    var userId: UUID?
    var playerName: String
    var playerHandle: String
    var playerAvatarURL: String?
    let date: Date
    let summitName: String
    let storyComment: String
    let elevationGainMeters: Int
    let durationSeconds: TimeInterval
    let distanceKilometers: Double
    let xpGained: Int
    let isCurrentUser: Bool
    var photoURL: String? = nil
    var pauseCount: Int = 0
    var totalPauseDuration: TimeInterval = 0
    var fistBumpCount: Int = 0
    var isFistBumped: Bool = false
    var commentCount: Int = 0
    var isBookmarked: Bool = false
    var routeCoordinates: [CLLocationCoordinate2D] = []  // Decoded route for map display
    var routeLocations: [CLLocation] = [] // Decoded route with altitude for elevation profile
}

// MARK: - Social models (Supabase rows)

struct CloudFistBump: Codable {
    let tour_id: UUID
    let user_id: UUID
}

struct CloudComment: Codable, Identifiable {
    let id: UUID?
    let tour_id: UUID
    let user_id: UUID
    let body: String
    let created_at: Date?
}

struct CloudBookmark: Codable {
    let tour_id: UUID
    let user_id: UUID
    let mountain_name: String
}

// MARK: - Comment UI model (denormalized for display)

struct CommentDisplay: Identifiable {
    let id: UUID
    let userName: String
    let userHandle: String
    let avatarURL: String?
    let body: String
    let date: Date
    let isCurrentUser: Bool
}
