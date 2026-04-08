import Foundation
import SwiftUI

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
// === SAVED ROUTE MODEL ===
// =========================================
struct SavedRoute: Identifiable, Codable {
    let id: UUID
    var name: String
    var mountainIds: [UUID]
    var createdAt: Date
    var totalDistanceKm: Double
    var totalElevationGain: Int
    var estimatedDurationMinutes: Int
    var difficulty: String

    enum CodingKeys: String, CodingKey {
        case id                       = "id"
        case name                     = "name"
        case mountainIds              = "mountain_ids"
        case createdAt                = "created_at"
        case totalDistanceKm          = "total_distance_km"
        case totalElevationGain       = "total_elevation_gain"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case difficulty               = "difficulty"
    }
}

// =========================================
// === THE DATABASE ===
// =========================================
struct MountainDatabase {
    static let mockUserPrestige: [UserMountainPrestige] = []
    
    // Die Berge werden jetzt asynchron über den MountainManager aus Supabase geladen.
    static var all: [Mountain] = []
    
    static var prestigePeaks: [Mountain] {
        all.filter { $0.isPrestigePeak }
    }
}
