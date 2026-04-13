import Foundation
import SwiftUI
import CoreLocation

// =========================================
// === 1. ENUMS ===
// =========================================
enum Difficulty: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case extreme = "Extreme"
    case expert = "Expert" // 🟢 HIER NEU HINZUGEFÜGT, um den Supabase-Crash zu fixen!

    var color: Color {
        switch self {
        case .easy:    return .green
        case .medium:  return .blue
        case .hard:    return .orange
        case .extreme: return .red
        case .expert:  return .purple // Neue Farbe für Expert-Berge
        }
    }
}

// =========================================
// === 2. MOUNTAIN MODEL ===
// =========================================
struct Mountain: Identifiable, Hashable, Codable {
    var id: UUID
    let name: String
    let elevation: Int
    let difficulty: Difficulty
    let country: String
    let region: String
    let description: String
    let isPrestigePeak: Bool
    let imageUrl: String?
    let image_url: String?
    var image_credit: String?
    var photographer_name: String?
    var photographer_link: String?
    let latitude: Double?
    let longitude: Double?
    var routes: [MountainRoute]?
    
    var effectiveImageUrl: String? {
        guard let url = image_url ?? imageUrl else { return nil }
        if url.contains(" ") {
            return url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        return url
    }

    // Explicit CodingKeys mapping exactly to Supabase column names (case-sensitive)
    enum CodingKeys: String, CodingKey {
        case id               = "id"
        case name             = "name"
        case elevation        = "elevation"
        case difficulty       = "difficulty"
        case country          = "country"
        case region           = "region"
        case description      = "description"
        case isPrestigePeak   = "isPrestigePeak"
        case imageUrl         = "imageUrl"
        case image_url        = "image_url"
        case image_credit     = "image_credit"
        case photographer_name = "photographer_name"
        case photographer_link = "photographer_link"
        case latitude         = "latitude"
        case longitude        = "longitude"
        case routes           = "routes"
    }

    // Safe decode: catches NULL values from Supabase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.elevation = try container.decode(Int.self, forKey: .elevation)
        
        if let diffStr = try container.decodeIfPresent(String.self, forKey: .difficulty), let diff = Difficulty(rawValue: diffStr) {
            self.difficulty = diff
        } else {
            self.difficulty = .medium
        }
        
        self.country = try container.decodeIfPresent(String.self, forKey: .country) ?? "Unknown"
        self.region = try container.decodeIfPresent(String.self, forKey: .region) ?? "Unknown Region"
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? "No description available."
        
        self.isPrestigePeak = try container.decodeIfPresent(Bool.self, forKey: .isPrestigePeak) ?? false
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        self.image_url = try container.decodeIfPresent(String.self, forKey: .image_url)
        self.image_credit = try container.decodeIfPresent(String.self, forKey: .image_credit)
        self.photographer_name = try container.decodeIfPresent(String.self, forKey: .photographer_name)
        self.photographer_link = try container.decodeIfPresent(String.self, forKey: .photographer_link)
        
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        
        self.routes = try container.decodeIfPresent([MountainRoute].self, forKey: .routes)
    }

    // Manual init for code that creates Mountain directly
    init(id: UUID = UUID(), name: String, elevation: Int, difficulty: Difficulty,
         country: String, region: String, description: String, isPrestigePeak: Bool,
         imageUrl: String? = nil, image_url: String? = nil, image_credit: String? = nil, photographer_name: String? = nil,
         photographer_link: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id; self.name = name; self.elevation = elevation
        self.difficulty = difficulty; self.country = country; self.region = region
        self.description = description; self.isPrestigePeak = isPrestigePeak
        self.imageUrl = imageUrl; self.image_url = image_url; self.image_credit = image_credit; self.photographer_name = photographer_name
        self.photographer_link = photographer_link
        self.latitude = latitude; self.longitude = longitude
    }

    var elevationFormatted: String {
        "\(elevation)m"
    }

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [DesignSystem.Colors.accent, Color.blue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// =========================================
// === MOUNTAIN ROUTE (NEW) ===
// =========================================
struct MountainRoute: Identifiable, Hashable, Codable {
    var id: UUID
    let mountain_id: UUID
    let route_name: String
    let start_lat: Double
    let start_lon: Double
    let route_polyline: String
    let elevation_profile: [Int]?
    
    var locations: [CLLocation] {
        let coords = PolylineUtility.decode(polyline: route_polyline)
        let elevs = elevation_profile ?? []
        return coords.enumerated().map { (i, coord) in
            let elevIndex = Int(round(Double(i) / Double(max(1, coords.count - 1)) * Double(max(0, elevs.count - 1))))
            let safeIndex = max(0, min(elevIndex, elevs.count - 1))
            let alt = elevs.isEmpty ? 0.0 : Double(elevs[safeIndex])
            return CLLocation(coordinate: coord, altitude: alt, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
        }
    }
}

// =========================================
// === PRESTIGE MODEL ===
// =========================================
struct UserMountainPrestige: Identifiable {
    let id = UUID()
    let mountain: Mountain
    var ascents: Int
    var bestTime: String?
    var score: Int
    var tier: PrestigeTier
}

enum PrestigeTier {
    case none, bronze, silver, gold, platinum, elite

    var label: String {
        switch self {
        case .none: return "Unranked"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .elite: return "Elite"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.dashed"
        case .bronze, .silver, .gold: return "medal.fill"
        case .platinum: return "star.circle.fill"
        case .elite: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .none: return DesignSystem.Colors.tertiaryText
        case .bronze: return Color.brown
        case .silver: return Color.gray
        case .gold: return Color.yellow
        case .platinum: return Color.cyan
        case .elite: return DesignSystem.Colors.prestige
        }
    }

    var minimumScore: Int {
        switch self {
        case .none: return 0
        case .bronze: return 10
        case .silver: return 25
        case .gold: return 50
        case .platinum: return 75
        case .elite: return 100
        }
    }

    var next: PrestigeTier? {
        switch self {
        case .none: return .bronze
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .platinum
        case .platinum: return .elite
        case .elite: return nil
        }
    }
}

// =========================================
// === SAVED ROUTE MODEL (Enhanced) ===
// =========================================
struct SavedRoute: Identifiable, Codable, Hashable {
    let id: UUID
    var user_id: UUID?
    var name: String
    var description: String
    var mountainIds: [UUID]
    var routePolyline: String?
    var coverImageUrl: String?
    var totalDistanceKm: Double
    var totalElevationGain: Int
    var estimatedDurationMinutes: Int
    var difficulty: String
    var visibility: RouteVisibility
    var tags: [String]
    var sportType: SportType
    var isCompleted: Bool
    var rating: Int?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id                       = "id"
        case user_id                  = "user_id"
        case name                     = "name"
        case description              = "description"
        case mountainIds              = "mountain_ids"
        case routePolyline            = "route_polyline"
        case coverImageUrl            = "cover_image_url"
        case totalDistanceKm          = "total_distance_km"
        case totalElevationGain       = "total_elevation_gain"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case difficulty               = "difficulty"
        case visibility               = "visibility"
        case tags                     = "tags"
        case sportType                = "sport_type"
        case isCompleted              = "is_completed"
        case rating                   = "rating"
        case createdAt                = "created_at"
        case updatedAt                = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        user_id = try c.decodeIfPresent(UUID.self, forKey: .user_id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        mountainIds = try c.decodeIfPresent([UUID].self, forKey: .mountainIds) ?? []
        routePolyline = try c.decodeIfPresent(String.self, forKey: .routePolyline)
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
        totalDistanceKm = try c.decodeIfPresent(Double.self, forKey: .totalDistanceKm) ?? 0
        totalElevationGain = try c.decodeIfPresent(Int.self, forKey: .totalElevationGain) ?? 0
        estimatedDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedDurationMinutes) ?? 0
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty) ?? "Medium"
        visibility = RouteVisibility(rawValue: try c.decodeIfPresent(String.self, forKey: .visibility) ?? "private") ?? .privateRoute
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        sportType = SportType(rawValue: try c.decodeIfPresent(String.self, forKey: .sportType) ?? "hiking") ?? .hiking
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    init(id: UUID = UUID(), user_id: UUID? = nil, name: String, description: String = "",
         mountainIds: [UUID] = [], routePolyline: String? = nil, coverImageUrl: String? = nil,
         totalDistanceKm: Double = 0, totalElevationGain: Int = 0, estimatedDurationMinutes: Int = 0,
         difficulty: String = "Medium", visibility: RouteVisibility = .privateRoute,
         tags: [String] = [], sportType: SportType = .hiking, isCompleted: Bool = false,
         rating: Int? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.user_id = user_id; self.name = name; self.description = description
        self.mountainIds = mountainIds; self.routePolyline = routePolyline
        self.coverImageUrl = coverImageUrl; self.totalDistanceKm = totalDistanceKm
        self.totalElevationGain = totalElevationGain; self.estimatedDurationMinutes = estimatedDurationMinutes
        self.difficulty = difficulty; self.visibility = visibility; self.tags = tags
        self.sportType = sportType; self.isCompleted = isCompleted; self.rating = rating
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    var durationFormatted: String {
        let h = estimatedDurationMinutes / 60
        let m = estimatedDurationMinutes % 60
        if h == 0 { return "\(m)min" }
        return m > 0 ? "\(h)h \(m)min" : "\(h)h"
    }

    var sportIcon: String { sportType.icon }
}

enum RouteVisibility: String, Codable, CaseIterable {
    case privateRoute = "private"
    case friends = "friends"
    case publicRoute = "public"

    var label: String {
        switch self {
        case .privateRoute: return "Private"
        case .friends: return "Friends"
        case .publicRoute: return "Public"
        }
    }

    var icon: String {
        switch self {
        case .privateRoute: return "lock.fill"
        case .friends: return "person.2.fill"
        case .publicRoute: return "globe"
        }
    }
}

enum SportType: String, Codable, CaseIterable {
    case hiking = "hiking"
    case trailRunning = "trail_running"
    case mountaineering = "mountaineering"
    case skiTouring = "ski_touring"
    case climbing = "climbing"

    var label: String {
        switch self {
        case .hiking: return "Hiking"
        case .trailRunning: return "Trail Running"
        case .mountaineering: return "Mountaineering"
        case .skiTouring: return "Ski Touring"
        case .climbing: return "Climbing"
        }
    }

    var icon: String {
        switch self {
        case .hiking: return "figure.hiking"
        case .trailRunning: return "figure.run"
        case .mountaineering: return "mountain.2.fill"
        case .skiTouring: return "figure.skiing.downhill"
        case .climbing: return "figure.climbing"
        }
    }
}

// =========================================
// === ROUTE FOLDER MODEL ===
// =========================================
struct RouteFolder: Identifiable, Codable, Hashable {
    let id: UUID
    let owner_id: UUID
    var name: String
    var description: String
    var cover_image_url: String?
    var visibility: String
    var color: String
    var icon: String
    var created_at: Date
    var updated_at: Date

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        owner_id = try c.decode(UUID.self, forKey: .owner_id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        cover_image_url = try c.decodeIfPresent(String.self, forKey: .cover_image_url)
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility) ?? "private"
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#2680FF"
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "folder.fill"
        created_at = try c.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try c.decodeIfPresent(Date.self, forKey: .updated_at) ?? Date()
    }

    init(id: UUID = UUID(), owner_id: UUID, name: String, description: String = "",
         cover_image_url: String? = nil, visibility: String = "private",
         color: String = "#2680FF", icon: String = "folder.fill",
         created_at: Date = Date(), updated_at: Date = Date()) {
        self.id = id; self.owner_id = owner_id; self.name = name; self.description = description
        self.cover_image_url = cover_image_url; self.visibility = visibility
        self.color = color; self.icon = icon; self.created_at = created_at; self.updated_at = updated_at
    }

    var isShared: Bool { visibility == "shared" || visibility == "public" }
    var accentColor: Color {
        Color(hex: color) ?? DesignSystem.Colors.accent
    }
}

struct RouteFolderMember: Identifiable, Codable {
    let id: UUID
    let folder_id: UUID
    let user_id: UUID
    let role: String
    let invited_by: UUID?
    let joined_at: Date

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        folder_id = try c.decode(UUID.self, forKey: .folder_id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "viewer"
        invited_by = try c.decodeIfPresent(UUID.self, forKey: .invited_by)
        joined_at = try c.decodeIfPresent(Date.self, forKey: .joined_at) ?? Date()
    }
}

struct RouteFolderRoute: Identifiable, Codable {
    let id: UUID
    let folder_id: UUID
    let route_id: UUID
    let added_by: UUID?
    let added_at: Date
    let sort_order: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        folder_id = try c.decode(UUID.self, forKey: .folder_id)
        route_id = try c.decode(UUID.self, forKey: .route_id)
        added_by = try c.decodeIfPresent(UUID.self, forKey: .added_by)
        added_at = try c.decodeIfPresent(Date.self, forKey: .added_at) ?? Date()
        sort_order = try c.decodeIfPresent(Int.self, forKey: .sort_order) ?? 0
    }
}

struct ShareableUser: Identifiable, Codable {
    let id: UUID
    let username: String
    let handle: String
    let avatar_url: String?
    var level: Int?
    var xp: Int?
}

// Color extension for hex parsing
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255.0,
                  green: Double((rgb >> 8) & 0xFF) / 255.0,
                  blue: Double(rgb & 0xFF) / 255.0)
    }
}

// =========================================
// === THE DATABASE ===
// =========================================
class MountainDatabase {
    static let shared = MountainDatabase()
    static let mockUserPrestige: [UserMountainPrestige] = []
    
    static var all: [Mountain] = []
    static var prestigePeaks: [Mountain] {
        all.filter { $0.isPrestigePeak }
    }
    
    private var mountainCache: [UUID: Mountain] = [:]
    
    func getMountains(ids: [UUID]) -> [Mountain]? {
        var result: [Mountain] = []
        for id in ids {
            if let m = mountainCache[id] {
                result.append(m)
            } else {
                return nil // not fully cached
            }
        }
        return result
    }
    
    func store(mountains: [Mountain]) {
        for m in mountains {
            mountainCache[m.id] = m
        }
    }
}
