import Foundation

// =========================================
// === DATEI: CloudProfile.swift ===
// === User profile row in Supabase `profiles` ===
// =========================================
//
// Pure data model. Lives outside AppState so the Service layer
// (ProfileService, future ones) can depend on the model without
// pulling in AppState as a transitive dependency.

struct CloudProfile: Codable, Identifiable {
    let id: UUID
    var username: String
    var handle: String
    var xp: Int
    var level: Int
    var avatar_url: String?
    var region: String?
    var insta_handle: String?
    var disciplines: [String]?
    var specialties: [String]?
    var hobbies: [String]?

    // Custom decoder for robust parsing in case DB rows have nulls
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "Alpinist"
        handle = try container.decodeIfPresent(String.self, forKey: .handle) ?? "climber"
        xp = try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        avatar_url = try container.decodeIfPresent(String.self, forKey: .avatar_url)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        insta_handle = try container.decodeIfPresent(String.self, forKey: .insta_handle)
        disciplines = try container.decodeIfPresent([String].self, forKey: .disciplines)
        specialties = try container.decodeIfPresent([String].self, forKey: .specialties)
        hobbies = try container.decodeIfPresent([String].self, forKey: .hobbies)
    }

    // Standard initializer to manually create profiles
    init(id: UUID, username: String, handle: String, xp: Int, level: Int, avatar_url: String?, region: String?, insta_handle: String? = nil, disciplines: [String]? = nil, specialties: [String]? = nil, hobbies: [String]? = nil) {
        self.id = id; self.username = username; self.handle = handle; self.xp = xp; self.level = level; self.avatar_url = avatar_url; self.region = region
        self.insta_handle = insta_handle; self.disciplines = disciplines; self.specialties = specialties; self.hobbies = hobbies
    }
}
