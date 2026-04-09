import Foundation
import SwiftUI
import Combine
import Supabase
import CoreLocation

// =========================================
// === DATEI: AppState.swift ===
// === Das Gehirn der App ===
// =========================================

// --- DATENMODELLE ---

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
    var is_public: Bool?
    var follower_count: Int?
    var following_count: Int?

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
        is_public = try container.decodeIfPresent(Bool.self, forKey: .is_public)
        follower_count = try container.decodeIfPresent(Int.self, forKey: .follower_count)
        following_count = try container.decodeIfPresent(Int.self, forKey: .following_count)
    }

    // Standard initializer to manually create profiles
    init(id: UUID, username: String, handle: String, xp: Int, level: Int, avatar_url: String?, region: String?, insta_handle: String? = nil, disciplines: [String]? = nil, specialties: [String]? = nil, hobbies: [String]? = nil, is_public: Bool? = nil, follower_count: Int? = nil, following_count: Int? = nil) {
        self.id = id; self.username = username; self.handle = handle; self.xp = xp; self.level = level; self.avatar_url = avatar_url; self.region = region
        self.insta_handle = insta_handle; self.disciplines = disciplines; self.specialties = specialties; self.hobbies = hobbies
        self.is_public = is_public; self.follower_count = follower_count; self.following_count = following_count
    }
}

struct AscendProfile: Codable {
    let user_id: UUID
    var ascend_xp: Double
    var ascend_level: Int
    var ascend_tier: String
    var ascend_subtier: Int
    var streak_days: Int
    var last_activity_date: Date?
    var prestige_mountains_completed: Int
}



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

/// Lightweight encoded polyline helpers for storing route data
struct RouteEncoder {
    /// Encode an array of CLLocation into a compact JSON string of [[lat,lon,alt],...]
    static func encode(_ locations: [CLLocation]) -> String? {
        guard !locations.isEmpty else { return nil }
        // Sample down to max 200 points for storage efficiency
        let step = max(1, locations.count / 200)
        var sampled: [[Double]] = []
        for i in stride(from: 0, to: locations.count, by: step) {
            let loc = locations[i]
            sampled.append([
                (loc.coordinate.latitude * 100000).rounded() / 100000,
                (loc.coordinate.longitude * 100000).rounded() / 100000,
                loc.altitude.rounded()
            ])
        }
        // Always include the last point
        if let last = locations.last {
            let lastEntry = [
                (last.coordinate.latitude * 100000).rounded() / 100000,
                (last.coordinate.longitude * 100000).rounded() / 100000,
                last.altitude.rounded()
            ]
            if sampled.last != lastEntry { sampled.append(lastEntry) }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: sampled) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode a JSON polyline string back into coordinates
    static func decode(_ polyline: String) -> [CLLocationCoordinate2D] {
        guard let data = polyline.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]] else { return [] }
        return arr.compactMap { point in
            guard point.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
        }
    }
}

struct PauseEntry: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let latitude: Double
    let longitude: Double
    let isAutomatic: Bool

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct FriendshipRule: Codable {
    let friend_id: UUID
}

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
}

// --- SOCIAL MODELS ---

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

struct CommentDisplay: Identifiable {
    let id: UUID
    let userName: String
    let userHandle: String
    let avatarURL: String?
    let body: String
    let date: Date
    let isCurrentUser: Bool
}

// --- HERO BANNER MODEL ---

struct HeroBannerItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: String?
    let badge: String?       // e.g. "PRESTIGE PEAK", "TRENDING", "COMMUNITY"
    let mountain: Mountain?  // nil for community highlights
}

// --- EQUIPMENT MODEL ---

struct EquipmentItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let brand: String
    let affiliateURL: String?
    let icon: String
    
    static func == (lhs: EquipmentItem, rhs: EquipmentItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct Equipment: Codable, Equatable {
    var head: String = "Beanie"
    var jacket: String = "Arc'teryx Alpha SV"
    var backpack: String = "Osprey Mutant 38"
    var pants: String = "Fjallraven Keb"
    var boots: String = "La Sportiva Nepal"
    var extras: String = "Petzl Ice Axes"
    
    // Affiliate URLs for each slot
    var headURL: String? = nil
    var jacketURL: String? = nil
    var backpackURL: String? = nil
    var pantsURL: String? = nil
    var bootsURL: String? = nil
    var extrasURL: String? = nil
}

// Equipment catalog with affiliate links
struct EquipmentCatalog {
    static let heads: [EquipmentItem] = [
        EquipmentItem(id: "h1", name: "Beanie", brand: "Patagonia", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h2", name: "Alpine Helmet", brand: "Petzl", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h3", name: "Sun Cap", brand: "Outdoor Research", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h4", name: "Balaclava", brand: "Arc'teryx", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h5", name: "Buff Headband", brand: "Buff", affiliateURL: nil, icon: "crown.fill"),
    ]
    
    static let jackets: [EquipmentItem] = [
        EquipmentItem(id: "j1", name: "Alpha SV", brand: "Arc'teryx", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j2", name: "Torrentshell 3L", brand: "Patagonia", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j3", name: "Bergwacht GTX", brand: "Mammut", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j4", name: "Kento HS", brand: "Mammut", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j5", name: "Nano Puff", brand: "Patagonia", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j6", name: "Cerium Down", brand: "Arc'teryx", affiliateURL: nil, icon: "tshirt.fill"),
    ]
    
    static let backpacks: [EquipmentItem] = [
        EquipmentItem(id: "b1", name: "Mutant 38", brand: "Osprey", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b2", name: "Trion 28", brand: "Mammut", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b3", name: "Alpinist 35", brand: "Osprey", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b4", name: "Storm 25", brand: "Blue Ice", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b5", name: "Cirriform 28", brand: "Black Diamond", affiliateURL: nil, icon: "backpack.fill"),
    ]
    
    static let pantsItems: [EquipmentItem] = [
        EquipmentItem(id: "p1", name: "Keb Trousers", brand: "Fjällräven", affiliateURL: nil, icon: "figure.walk"),
        EquipmentItem(id: "p2", name: "Gamma MX", brand: "Arc'teryx", affiliateURL: nil, icon: "figure.walk"),
        EquipmentItem(id: "p3", name: "Courmayeur Pants", brand: "Salewa", affiliateURL: nil, icon: "figure.walk"),
        EquipmentItem(id: "p4", name: "Eisfeld Light", brand: "Mammut", affiliateURL: nil, icon: "figure.walk"),
    ]
    
    static let bootsItems: [EquipmentItem] = [
        EquipmentItem(id: "s1", name: "Nepal Cube", brand: "La Sportiva", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s2", name: "Trango Tower", brand: "La Sportiva", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s3", name: "Kento Advanced", brand: "Mammut", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s4", name: "G2 Evo", brand: "Scarpa", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s5", name: "Phantom 6000", brand: "Scarpa", affiliateURL: nil, icon: "shoe.fill"),
    ]
    
    static let extrasItems: [EquipmentItem] = [
        EquipmentItem(id: "e1", name: "Ice Axes", brand: "Petzl", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e2", name: "Trekking Poles", brand: "Black Diamond", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e3", name: "Headlamp", brand: "Petzl", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e4", name: "Crampons", brand: "Grivel", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e5", name: "Carabiners Set", brand: "DMM", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e6", name: "GPS Watch", brand: "Garmin", affiliateURL: nil, icon: "hammer.fill"),
    ]
    
    static func items(for slot: String) -> [EquipmentItem] {
        switch slot {
        case "Head": return heads
        case "Jacket": return jackets
        case "Pack": return backpacks
        case "Pants": return pantsItems
        case "Boots": return bootsItems
        case "Extras": return extrasItems
        default: return []
        }
    }
}


// --- HAUPTKLASSE ---

@MainActor
class AppState: ObservableObject {
    
    // Lokale User-Daten
    @Published var userName: String = "New Alpinist"
    @Published var userHandle: String = "climber"
    @Published var selectedSports: [String] = []
    @Published var profileImage: Data? = nil
    @Published var avatarURL: String? = nil
    @Published var userRegion: String = "" // Standardmäßig leer
    // Neue Profile-Eigenschaften (Mock für UI)
    @Published var instaHandle: String = "alpinist_life"
    @Published var mountaineeringSpecialties: [String] = ["Ice Climbing", "Scrambling"]
    @Published var otherHobbies: [String] = ["Boxing", "Soccer"]
    @Published var equipment: Equipment = Equipment()

    // Privacy & follow graph
    @Published var isProfilePublic: Bool = true
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var followingIds: Set<UUID> = []
    
    // Fortschritt
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    
    // Ascend Progress
    @Published var ascendProfile: AscendProfile? = nil

    
    // Feeds & Leaderboards
    @Published var recentTours: [Tour] = []
    @Published var bookmarkedTours: [Tour] = []
    @Published var friendsLeaderboard: [CloudProfile] = []
    @Published var globalLeaderboard: [CloudProfile] = []
    @Published var localLeaderboard: [CloudProfile] = []

    // Discovery
    @Published var recommendedPeaks: [Mountain] = []
    @Published var heroBannerItems: [HeroBannerItem] = []
    @Published var suggestedRoutes: [Mountain] = []

    // Collections (shared across all pages)
    @Published var myCollections: [TourCollection] = []

    // FAB Visibility (driven by scroll direction in child views)
    @Published var isFABVisible: Bool = true

    // Pagination
    @Published var isLoadingMoreFeed: Bool = false
    @Published var hasMoreFeed: Bool = true
    private var feedPage: Int = 0
    private let feedPageSize: Int = 10
    private let feedMaxItems: Int = 50

    var currentLevelProgressXP: Int { currentXP % 1000 }
    var xpNeededForNextLevel: Int { 1000 }

    // Weekly objectives helpers
    var weeklyTours: [Tour] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return recentTours.filter { $0.isCurrentUser && weekInterval.contains($0.date) }
    }
    var weeklyElevation: Int { weeklyTours.reduce(0) { $0 + $1.elevationGainMeters } }
    var weeklyTourCount: Int { weeklyTours.count }
    
    // Automatische Berechnung des Rangs anhand des aktuellen Levels!
    func syncAscendTierWithCurrentLevel() {
        guard ascendProfile != nil else { return }
        
        // Finde den Rang, in dessen Level-Range wir uns befinden
        let roadmapTiers = AscendRoadmapData.shared.tiers
        if let matchedTier = roadmapTiers.first(where: { currentLevel >= $0.startLvl && currentLevel <= $0.endLvl }) {
            let parts = matchedTier.name.split(separator: " ")
            let baseTier = String(parts[0]) // z.B. "Bronze"
            
            var subtier = 1
            if parts.count > 1 {
                let numeral = String(parts[1])
                if numeral == "II" { subtier = 2 }
                else if numeral == "III" { subtier = 3 }
            }
            // Obsidian hat keine Subtier-Angabe im Namen, bleibt bei 1
            
            ascendProfile?.ascend_tier = baseTier
            ascendProfile?.ascend_subtier = subtier
            ascendProfile?.ascend_level = self.currentLevel
            ascendProfile?.ascend_xp = Double(self.currentXP) // XP fix!
        }
    }
    
    // --- PROFIL FUNKTIONEN ---
    
    // Lädt dein Profil beim Start
    func fetchProfileFromCloud() {
        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                let profile: CloudProfile = try await supabase.from("profiles").select().eq("id", value: userId).single().execute().value
                
                self.userName = profile.username
                self.userHandle = profile.handle
                self.currentXP = profile.xp
                self.currentLevel = profile.level
                self.avatarURL = profile.avatar_url
                self.userRegion = profile.region ?? ""
                self.instaHandle = profile.insta_handle ?? ""
                self.selectedSports = profile.disciplines ?? []
                self.mountaineeringSpecialties = profile.specialties ?? []
                self.otherHobbies = profile.hobbies ?? []
                self.isProfilePublic = profile.is_public ?? true
                self.followerCount = profile.follower_count ?? 0
                self.followingCount = profile.following_count ?? 0

                fetchFollowing()
                fetchLeaderboard()
                fetchFeed()
                fetchAscendProfile()
                fetchCollections()
                fetchBookmarkedTours()
            } catch {
                if self.userHandle == "climber" {
                    self.userHandle = "climber_\(Int.random(in: 1000...9999))"
                }
                uploadProfileToCloud()
            }
        }
    }
    
    // Speichert einfache Änderungen wie XP
    func uploadProfileToCloud(refreshLeaderboard: Bool = false) {
        Task {
            do {
                let session = try await supabase.auth.session
                let updatedProfile = CloudProfile(id: session.user.id, username: self.userName, handle: self.userHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: self.avatarURL, region: self.userRegion, insta_handle: self.instaHandle, disciplines: self.selectedSports, specialties: self.mountaineeringSpecialties, hobbies: self.otherHobbies)
                try await supabase.from("profiles").upsert(updatedProfile).execute()
                if refreshLeaderboard { fetchLeaderboard() }
            } catch { print("❌ Fehler beim Speichern: \(error)") }
        }
    }
    
    // Lädt das Ascend Profil (Level, Tier, XP)
    func fetchAscendProfile() {
        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                let result: AscendProfile = try await supabase
                    .from("ascend_profiles")
                    .select()
                    .eq("user_id", value: userId)
                    .single()
                    .execute()
                    .value
                
                self.ascendProfile = result
                self.syncAscendTierWithCurrentLevel() // <- Hier wird der korrekte dynamische Rang ermittelt!
                
            } catch {
                print("⚠️ Fetch Ascend Profile: \(error)")
                // Create dummy or insert if not exists
                self.ascendProfile = AscendProfile(
                    user_id: UUID(),
                    ascend_xp: 0,
                    ascend_level: 1,
                    ascend_tier: "Bronze",
                    ascend_subtier: 1,
                    streak_days: 0,
                    last_activity_date: nil,
                    prestige_mountains_completed: 0
                )
                self.syncAscendTierWithCurrentLevel() // <- Selbst beim leeren Start der richtige Rang
            }
        }
    }
    
    // Speichert Profil-Einstellungen aus dem Edit-Fenster
    func updateProfileSettings(newName: String, newHandle: String, newRegion: String, newSports: [String], newInsta: String, newHobbies: [String], newSpecialties: [String]) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let updatedProfile = CloudProfile(id: session.user.id, username: newName, handle: newHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: self.avatarURL, region: newRegion, insta_handle: newInsta, disciplines: newSports, specialties: newSpecialties, hobbies: newHobbies)
            try await supabase.from("profiles").upsert(updatedProfile).execute()

            // Register each custom-ish hobby into shared dictionary (fire-and-forget)
            for hobby in newHobbies {
                Task.detached { try? await HobbiesRepository.shared.register(name: hobby) }
            }

            self.userName = newName; self.userHandle = newHandle; self.userRegion = newRegion; self.selectedSports = newSports
            self.instaHandle = newInsta; self.otherHobbies = newHobbies; self.mountaineeringSpecialties = newSpecialties
            
            // Reactively update Feed 
            for i in self.recentTours.indices where self.recentTours[i].userId == session.user.id {
                self.recentTours[i].playerName = newName
                self.recentTours[i].playerHandle = newHandle
                self.recentTours[i].playerAvatarURL = self.avatarURL
            }
            
            fetchLeaderboard()  // Region may change → local leaderboard must refresh
            return true
        } catch {
            print("❌ updateProfileSettings error: \(error)")
            return false
        }
    }
    
    // Lädt ein neues Profilbild hoch und aktualisiert die URL
    func uploadProfilePicture(data: Data) {
        Task {
            do {
                let userId = try await supabase.auth.session.user.id
                let path = "\(userId).jpg"
                try await supabase.storage.from("avatars").upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
                
                let cacheBusterURL = publicURL.absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"
                await MainActor.run { self.avatarURL = cacheBusterURL }
                
                let updatedProfile = CloudProfile(id: userId, username: self.userName, handle: self.userHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: cacheBusterURL, region: self.userRegion, insta_handle: self.instaHandle, disciplines: self.selectedSports, specialties: self.mountaineeringSpecialties, hobbies: self.otherHobbies)
                try await supabase.from("profiles").upsert(updatedProfile).execute()
                // No leaderboard/feed refresh needed — only avatar URL changed
            } catch { print("❌ Fehler beim Bild-Upload: \(error)") }
        }
    }

    // --- TOUR FUNKTIONEN ---
    
    // Holt die erste Seite des Feeds (Reset)
    func fetchFeed() {
        feedPage = 0
        hasMoreFeed = true
        recentTours = []
        loadFeedPage()
    }

    // Lädt die nächste Seite für Infinite Scroll (max 50 items)
    func loadMoreFeed() {
        guard !isLoadingMoreFeed && hasMoreFeed && recentTours.count < feedMaxItems else { return }
        loadFeedPage()
    }

    // Interne Pagination-Logik
    private func loadFeedPage() {
        guard !isLoadingMoreFeed else { return }
        isLoadingMoreFeed = true

        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let myFriendships: [FriendshipRule] = try await supabase.from("friendships").select("friend_id").eq("user_id", value: myId).execute().value

                var relevantIds = myFriendships.map { $0.friend_id }
                relevantIds.append(myId)

                let profiles: [CloudProfile] = try await supabase.from("profiles").select("id,username,handle,avatar_url,xp,level,region").in("id", values: relevantIds).execute().value

                let rangeStart = feedPage * feedPageSize
                let rangeEnd = rangeStart + feedPageSize - 1

                let cloudTours: [CloudTour] = try await supabase.from("tours")
                    .select()
                    .in("user_id", values: relevantIds)
                    .order("date", ascending: false)
                    .range(from: rangeStart, to: rangeEnd)
                    .execute()
                    .value

                // Alle tour IDs sammeln für Social-Queries
                let tourIds = cloudTours.compactMap { $0.id }

                // Fist bumps, comments, bookmarks TRULY in parallel laden
                var allBumps: [CloudFistBump] = []
                var allCommentCounts: [UUID: Int] = [:]
                var myBookmarks: Set<UUID> = []

                var bumpsByTour: [UUID: [CloudFistBump]] = [:]

                if !tourIds.isEmpty {
                    struct CommentRow: Codable { let tour_id: UUID }
                    struct BookmarkRow: Codable { let tour_id: UUID }

                    async let bumpsTask: [CloudFistBump] = (try? supabase.from("fist_bumps").select().in("tour_id", values: tourIds).execute().value) ?? []
                    async let commentsTask: [CommentRow] = (try? supabase.from("comments").select("tour_id").in("tour_id", values: tourIds).execute().value) ?? []
                    async let bookmarksTask: [BookmarkRow] = (try? supabase.from("bookmarked_routes").select("tour_id").eq("user_id", value: myId).in("tour_id", values: tourIds).execute().value) ?? []

                    allBumps = await bumpsTask
                    // Build Dictionary for O(1) lookup per tour instead of O(n) filter
                    for bump in allBumps {
                        bumpsByTour[bump.tour_id, default: []].append(bump)
                    }
                    let commentRows = await commentsTask
                    for row in commentRows {
                        allCommentCounts[row.tour_id, default: 0] += 1
                    }
                    myBookmarks = Set((await bookmarksTask).map { $0.tour_id })
                }

                // Reuse single decoder instance instead of creating one per tour
                let pauseDecoder = JSONDecoder()
                pauseDecoder.dateDecodingStrategy = .iso8601
                // Build profile lookup dict to avoid O(n²) .first(where:) per tour
                let profileLookup = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

                var pageTours: [Tour] = []
                for tour in cloudTours {
                    if let player = profileLookup[tour.user_id] {
                        var parsedPauseCount = 0
                        var parsedPauseDuration: TimeInterval = 0
                        if let json = tour.pauses, let data = json.data(using: .utf8) {
                            if let entries = try? pauseDecoder.decode([PauseEntry].self, from: data) {
                                parsedPauseCount = entries.count
                                parsedPauseDuration = entries.reduce(0) { $0 + $1.duration }
                            }
                        }

                        let tourBumps = tour.id.flatMap { bumpsByTour[$0] } ?? []

                        // Decode route polyline if available
                        let routeCoords = tour.route_polyline.flatMap { RouteEncoder.decode($0) } ?? []

                        let feedTour = Tour(
                            cloudId: tour.id,
                            userId: player.id,
                            playerName: player.username,
                            playerHandle: player.handle,
                            playerAvatarURL: player.avatar_url,
                            date: tour.date,
                            summitName: tour.name,
                            storyComment: tour.notes,
                            elevationGainMeters: tour.elevation,
                            durationSeconds: TimeInterval(tour.duration_seconds ?? 0),
                            distanceKilometers: tour.distance_km ?? 0.0,
                            xpGained: XPCalculator.xp(elevation: tour.elevation, difficulty: Difficulty(rawValue: tour.difficulty) ?? .medium, isPrestigePeak: false),
                            isCurrentUser: player.id == myId,
                            photoURL: tour.photo_url,
                            pauseCount: parsedPauseCount,
                            totalPauseDuration: parsedPauseDuration,
                            fistBumpCount: tourBumps.count,
                            isFistBumped: tourBumps.contains { $0.user_id == myId },
                            commentCount: tour.id != nil ? allCommentCounts[tour.id!] ?? 0 : 0,
                            isBookmarked: tour.id != nil ? myBookmarks.contains(tour.id!) : false,
                            routeCoordinates: routeCoords
                        )
                        pageTours.append(feedTour)
                    }
                }

                print("📡 Feed loaded: \(cloudTours.count) cloud tours → \(pageTours.count) display tours (profiles matched: \(profiles.count))")
                self.recentTours.append(contentsOf: pageTours)
                self.feedPage += 1
                self.hasMoreFeed = cloudTours.count == self.feedPageSize
                self.isLoadingMoreFeed = false
            } catch {
                print("❌ Fehler beim Feed laden: \(error)")
                self.isLoadingMoreFeed = false
            }
        }
    }

    // Lädt die Touren, die der Benutzer gespeichert (gebookmarkt) hat
    func fetchBookmarkedTours() {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                
                // 1. Hole referenzierte Tour-IDs aus der Bookmark-Tabelle
                struct BookmarkRow: Codable { let tour_id: UUID }
                let bookmarks: [BookmarkRow] = try await supabase
                    .from("bookmarked_routes")
                    .select("tour_id")
                    .eq("user_id", value: myId)
                    .execute()
                    .value
                    
                let tourIds = bookmarks.map { $0.tour_id }
                if tourIds.isEmpty {
                    await MainActor.run { self.bookmarkedTours = [] }
                    return
                }

                // 2. Hole die echten Tour-Daten
                let cloudTours: [CloudTour] = try await supabase
                    .from("tours")
                    .select()
                    .in("id", values: tourIds)
                    .order("date", ascending: false)
                    .execute()
                    .value
                    
                // 3. Hole Profile für diese Touren
                let userIds = Array(Set(cloudTours.map { $0.user_id }))
                let profiles: [CloudProfile] = try await supabase
                    .from("profiles")
                    .select("id,username,handle,avatar_url,xp,level,region")
                    .in("id", values: userIds)
                    .execute()
                    .value
                let profileLookup = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
                
                // 4. Hole social interactions analog zum Feed
                var allBumps: [CloudFistBump] = []
                var allCommentCounts: [UUID: Int] = [:]
                var bumpsByTour: [UUID: [CloudFistBump]] = [:]

                struct CommentRow: Codable { let tour_id: UUID }
                async let bumpsTask: [CloudFistBump] = (try? supabase.from("fist_bumps").select().in("tour_id", values: tourIds).execute().value) ?? []
                async let commentsTask: [CommentRow] = (try? supabase.from("comments").select("tour_id").in("tour_id", values: tourIds).execute().value) ?? []

                allBumps = await bumpsTask
                for bump in allBumps { bumpsByTour[bump.tour_id, default: []].append(bump) }
                for row in await commentsTask { allCommentCounts[row.tour_id, default: 0] += 1 }

                let pauseDecoder = JSONDecoder()
                pauseDecoder.dateDecodingStrategy = .iso8601
                
                // 5. Baue Touren
                var builtTours: [Tour] = []
                for tour in cloudTours {
                    if let player = profileLookup[tour.user_id] {
                        var parsedPauseCount = 0
                        var parsedPauseDuration: TimeInterval = 0
                        if let json = tour.pauses, let data = json.data(using: .utf8) {
                            if let entries = try? pauseDecoder.decode([PauseEntry].self, from: data) {
                                parsedPauseCount = entries.count
                                parsedPauseDuration = entries.reduce(0) { $0 + $1.duration }
                            }
                        }

                        let tourBumps = tour.id.flatMap { bumpsByTour[$0] } ?? []
                        let routeCoords = tour.route_polyline.flatMap { RouteEncoder.decode($0) } ?? []

                        builtTours.append(Tour(
                            cloudId: tour.id,
                            userId: player.id,
                            playerName: player.username,
                            playerHandle: player.handle,
                            playerAvatarURL: player.avatar_url,
                            date: tour.date,
                            summitName: tour.name,
                            storyComment: tour.notes,
                            elevationGainMeters: tour.elevation,
                            durationSeconds: TimeInterval(tour.duration_seconds ?? 0),
                            distanceKilometers: tour.distance_km ?? 0.0,
                            xpGained: XPCalculator.xp(elevation: tour.elevation, difficulty: Difficulty(rawValue: tour.difficulty) ?? .medium, isPrestigePeak: false),
                            isCurrentUser: player.id == myId,
                            photoURL: tour.photo_url,
                            pauseCount: parsedPauseCount,
                            totalPauseDuration: parsedPauseDuration,
                            fistBumpCount: tourBumps.count,
                            isFistBumped: tourBumps.contains { $0.user_id == myId },
                            commentCount: tour.id != nil ? allCommentCounts[tour.id!] ?? 0 : 0,
                            isBookmarked: true, // It is explicitly bookmarked since we fetched it from bookmarked_routes
                            routeCoordinates: routeCoords
                        ))
                    }
                }
                
                await MainActor.run {
                    self.bookmarkedTours = builtTours
                }
            } catch {
                print("❌ Fehler beim Laden der markierten Touren: \(error)")
            }
        }
    }
    func addCompletedTour(summit: String, comment: String, elevation: Int, duration: TimeInterval, distance: Double, xp: Int, pauses: [PauseEntry] = [], photoData: Data? = nil, rawRoute: [CLLocation] = []) {
        self.currentXP += xp
        self.currentLevel = (self.currentXP / 1000) + 1
        self.syncAscendTierWithCurrentLevel() // Update Rank if user leveled up

        uploadProfileToCloud(refreshLeaderboard: true)  // Tour completed = XP changed = leaderboard needs refresh
        fetchCollections() // Refresh collections in case mountain was added to one
        
        // Optional: Update ascend_profiles DB if we want it permanently saved.
        // We'll trust the sync on fetch, but pushing the new level is clean.
        if let profile = self.ascendProfile {
            Task {
                try? await supabase.from("ascend_profiles").upsert(profile).execute()
            }
        }

        Task {
            let myId: UUID
            do {
                myId = try await supabase.auth.session.user.id
            } catch {
                print("❌ Fehler beim Auth: \(error)")
                return
            }

            var pausesJSON: String? = nil
            if !pauses.isEmpty {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(pauses) {
                    pausesJSON = String(data: data, encoding: .utf8)
                }
            }

            // Resize photo on background thread to avoid UI freeze
            var compressedPhoto: Data? = nil
            if let photoData {
                compressedPhoto = await Task.detached(priority: .userInitiated) {
                    guard let uiImage = UIImage(data: photoData) else { return nil as Data? }
                    let maxDim: CGFloat = 800
                    let scale = min(maxDim / max(uiImage.size.width, uiImage.size.height), 1.0)
                    let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: newSize)
                    let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
                    return resized.jpegData(compressionQuality: 0.6)
                }.value
                if let compressed = compressedPhoto {
                    print("📸 Photo prepared (\(compressed.count / 1024)KB)")
                }
            }

            // Upload photo first (retry), then insert tour with photo_url
            var photoURL: String? = nil
            if let compressed = compressedPhoto {
                let photoPath = "\(myId)/\(UUID().uuidString).jpg"
                for attempt in 1...3 {
                    do {
                        try await supabase.storage.from("tour-photos").upload(photoPath, data: compressed, options: FileOptions(contentType: "image/jpeg"))
                        let publicURL = try supabase.storage.from("tour-photos").getPublicURL(path: photoPath)
                        photoURL = publicURL.absoluteString
                        print("📸 Photo uploaded (attempt \(attempt))")
                        break
                    } catch {
                        print("⚠️ Photo upload attempt \(attempt) failed: \(error.localizedDescription)")
                        if attempt < 3 {
                            try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                        }
                    }
                }
            }

            // Encode route polyline for storage
            let routePolyline = RouteEncoder.encode(rawRoute)

            // Insert tour (with photo_url if upload succeeded) — retry up to 3 times
            let newCloudTour = CloudTour(
                id: nil,
                user_id: myId,
                name: summit,
                elevation: elevation,
                date: Date(),
                difficulty: "Medium",
                notes: comment,
                duration_seconds: Int(duration),
                distance_km: distance,
                pauses: pausesJSON,
                photo_url: photoURL,
                route_polyline: routePolyline
            )

            for attempt in 1...3 {
                do {
                    try await supabase.from("tours").insert(newCloudTour).execute()
                    print("✅ Tour erfolgreich hochgeladen: \(summit) (attempt \(attempt))")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    fetchFeed()
                    return
                } catch {
                    print("⚠️ Tour insert attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                    } else {
                        print("❌ Tour konnte nach 3 Versuchen nicht gespeichert werden")
                    }
                }
            }
        }
    }

    // Löscht eine Tour
    func deleteTour(tour: Tour) {
        self.currentXP = max(0, self.currentXP - tour.xpGained)
        self.currentLevel = max(1, (self.currentXP / 1000) + 1)
        self.recentTours.removeAll { $0.id == tour.id }
        uploadProfileToCloud(refreshLeaderboard: true)

        Task {
            do {
                if let cloudId = tour.cloudId {
                    try await supabase.from("tours").delete().eq("id", value: cloudId).execute()
                } else {
                    let myId = try await supabase.auth.session.user.id
                    try await supabase.from("tours").delete().eq("user_id", value: myId).eq("name", value: tour.summitName).execute()
                }
            } catch { print("❌ Fehler beim Löschen der Tour: \(error)") }
        }
    }

    // --- SOCIAL FUNKTIONEN ---

    // Fist Bump (Like) toggeln
    func toggleFistBump(tour: Tour) {
        guard let tourId = tour.cloudId else { return }
        let wasBumped = tour.isFistBumped
        
        // Optimistic UI Update -> Verhindert, dass der Feed neu lädt und springt
        if let idx = recentTours.firstIndex(where: { $0.id == tour.id }) {
            recentTours[idx].isFistBumped.toggle()
            recentTours[idx].fistBumpCount += wasBumped ? -1 : 1
        }
        
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                if wasBumped {
                    try await supabase.from("fist_bumps").delete().eq("tour_id", value: tourId).eq("user_id", value: myId).execute()
                } else {
                    try await supabase.from("fist_bumps").insert(CloudFistBump(tour_id: tourId, user_id: myId)).execute()
                }
                // fetchFeed() wird hier NICHT mehr gerufen, um Scroll-Jumping zu verhindern
            } catch { print("❌ Fehler beim Fist Bump: \(error)") }
        }
    }

    // Kommentar posten
    func postComment(tour: Tour, body: String) {
        guard let tourId = tour.cloudId, !body.isEmpty else { return }
        
        // Optimistic Update für den Comment-Zähler
        if let idx = recentTours.firstIndex(where: { $0.id == tour.id }) {
            recentTours[idx].commentCount += 1
        }
        
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let comment = CloudComment(id: nil, tour_id: tourId, user_id: myId, body: body, created_at: nil)
                try await supabase.from("comments").insert(comment).execute()
                // fetchFeed() wird hier absichtlich weggelassen
            } catch { print("❌ Fehler beim Kommentieren: \(error)") }
        }
    }

    // Kommentare für eine Tour laden
    func fetchComments(tour: Tour) async -> [CommentDisplay] {
        guard let tourId = tour.cloudId else { return [] }
        do {
            let myId = try await supabase.auth.session.user.id
            struct FullComment: Codable {
                let id: UUID; let tour_id: UUID; let user_id: UUID; let body: String; let created_at: Date
            }
            let rows: [FullComment] = try await supabase.from("comments").select().eq("tour_id", value: tourId).order("created_at", ascending: true).execute().value
            let userIds = Array(Set(rows.map { $0.user_id }))
            let profiles: [CloudProfile] = try await supabase.from("profiles").select("id,username,handle,avatar_url,xp,level,region").in("id", values: userIds).execute().value
            let profileLookup = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            return rows.map { row in
                let profile = profileLookup[row.user_id]
                return CommentDisplay(
                    id: row.id,
                    userName: profile?.username ?? "Unknown",
                    userHandle: profile?.handle ?? "user",
                    avatarURL: profile?.avatar_url,
                    body: row.body,
                    date: row.created_at,
                    isCurrentUser: row.user_id == myId
                )
            }
        } catch {
            print("❌ Fehler beim Laden der Kommentare: \(error)")
            return []
        }
    }

    // Bookmark toggeln
    func toggleBookmark(tour: Tour) {
        guard let tourId = tour.cloudId else { return }
        let wasBookmarked = tour.isBookmarked
        
        // Optimistic Update
        if let idx = recentTours.firstIndex(where: { $0.id == tour.id }) {
            recentTours[idx].isBookmarked.toggle()
        }
        
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                if wasBookmarked {
                    try await supabase.from("bookmarked_routes").delete().eq("tour_id", value: tourId).eq("user_id", value: myId).execute()
                } else {
                    try await supabase.from("bookmarked_routes").insert(CloudBookmark(tour_id: tourId, user_id: myId, mountain_name: tour.summitName)).execute()
                }
                // fetchFeed() wird hier absichtlich weggelassen
            } catch { print("❌ Fehler beim Bookmark: \(error)") }
        }
    }

    // --- FOLLOW / SEARCH / PRIVACY ---

    /// Load the IDs of all users I currently follow.
    func fetchFollowing() {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                struct Row: Codable { let followed_id: UUID }
                let rows: [Row] = try await supabase
                    .from("follows")
                    .select("followed_id")
                    .eq("follower_id", value: myId)
                    .execute()
                    .value
                await MainActor.run {
                    self.followingIds = Set(rows.map { $0.followed_id })
                    self.followingCount = rows.count
                }
            } catch { print("⚠️ fetchFollowing: \(error)") }
        }
    }

    func isFollowing(_ userId: UUID) -> Bool {
        followingIds.contains(userId)
    }

    /// Follow another user. Optimistic update.
    func follow(userId: UUID) {
        guard !followingIds.contains(userId) else { return }
        followingIds.insert(userId)
        followingCount += 1
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                guard myId != userId else { return }
                struct NewFollow: Codable { let follower_id: UUID; let followed_id: UUID }
                try await supabase.from("follows").insert(NewFollow(follower_id: myId, followed_id: userId)).execute()
            } catch {
                print("❌ follow: \(error)")
                await MainActor.run {
                    self.followingIds.remove(userId)
                    self.followingCount = max(0, self.followingCount - 1)
                }
            }
        }
    }

    /// Unfollow a user. Optimistic update.
    func unfollow(userId: UUID) {
        guard followingIds.contains(userId) else { return }
        followingIds.remove(userId)
        followingCount = max(0, followingCount - 1)
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                try await supabase
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: myId)
                    .eq("followed_id", value: userId)
                    .execute()
            } catch {
                print("❌ unfollow: \(error)")
                await MainActor.run {
                    self.followingIds.insert(userId)
                    self.followingCount += 1
                }
            }
        }
    }

    /// Toggle my own profile visibility.
    func setProfilePublic(_ isPublic: Bool) {
        self.isProfilePublic = isPublic
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                struct PrivacyPatch: Codable { let is_public: Bool }
                try await supabase
                    .from("profiles")
                    .update(PrivacyPatch(is_public: isPublic))
                    .eq("id", value: myId)
                    .execute()
            } catch { print("❌ setProfilePublic: \(error)") }
        }
    }

    /// Fetch live follower/following count for any user.
    func fetchFollowCounts(for userId: UUID) async -> (followers: Int, following: Int) {
        do {
            let profiles: [CloudProfile] = try await supabase
                .from("profiles")
                .select("id,follower_count,following_count,username,handle,xp,level,avatar_url,region")
                .eq("id", value: userId)
                .execute()
                .value
            if let p = profiles.first {
                return (p.follower_count ?? 0, p.following_count ?? 0)
            }
        } catch { print("⚠️ fetchFollowCounts: \(error)") }
        return (0, 0)
    }

    /// Search users by username or handle via RPC.
    func searchUsers(query: String) async -> [CloudProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else { return [] }
        do {
            let params: [String: String] = ["q": trimmed]
            let results: [CloudProfile] = try await supabase
                .rpc("search_users", params: params)
                .execute()
                .value
            return results
        } catch {
            // Fallback: direct ilike query
            do {
                let results: [CloudProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .or("username.ilike.%\(trimmed)%,handle.ilike.%\(trimmed)%")
                    .order("xp", ascending: false)
                    .limit(30)
                    .execute()
                    .value
                return results
            } catch {
                print("❌ searchUsers fallback: \(error)")
                return []
            }
        }
    }

    // Fügt einen Freund anhand des Handles hinzu
    func addFriend(handleToSearch: String) {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let friendProfiles: [CloudProfile] = try await supabase.from("profiles").select().ilike("handle", pattern: handleToSearch).execute().value
                
                guard let friend = friendProfiles.first, friend.id != myId else { return }
                
                // First verify client-side if already a friend
                let alreadyFriends = self.friendsLeaderboard.contains { $0.id == friend.id }
                if alreadyFriends { return }
                
                struct NewFriendship: Codable { let user_id: UUID; let friend_id: UUID }
                do {
                    try await supabase.from("friendships").insert(NewFriendship(user_id: myId, friend_id: friend.id)).execute()
                } catch {
                    // Suppress unique constraint violations
                    let errStr = String(describing: error)
                    if !errStr.contains("23505") {
                        print("❌ Fehler beim Einfügen: \(error)")
                    } else {
                        print("ℹ️ Friendship already exists in DB.")
                    }
                }
                
                fetchLeaderboard()
                fetchFeed()
            } catch { print("❌ Fehler in addFriend: \(error)") }
        }
    }
    
    // Holt die drei Leaderboard-Listen parallel, aber fehlertolerant
    func fetchLeaderboard() {
        Task {
            let myId: UUID
            do {
                myId = try await supabase.auth.session.user.id
            } catch {
                print("❌ Fetch Leaderboard failed: no active session.")
                return
            }
            
            let myProfile = CloudProfile(id: myId, username: self.userName, handle: self.userHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: self.avatarURL, region: self.userRegion)
            let region = self.userRegion

            // 1. Fetch Friendships
            var friendIds: [UUID] = []
            do {
                let myFriendships: [FriendshipRule] = try await supabase.from("friendships").select("friend_id").eq("user_id", value: myId).execute().value
                friendIds = myFriendships.map { $0.friend_id }
            } catch {
                print("⚠️ Warning: Fetching friendships failed: \(error)")
            }

            // 2. Load Global
            do {
                var globalData: [CloudProfile] = try await supabase.from("profiles").select().order("xp", ascending: false).limit(1000).execute().value
                await MainActor.run { self.globalLeaderboard = globalData }
            } catch {
                print("⚠️ Warning: Loading global leaderboard failed: \(error)")
            }

            // 3. Load Local
            if !region.isEmpty {
                do {
                    var localData: [CloudProfile] = try await supabase.from("profiles").select().eq("region", value: region).order("xp", ascending: false).limit(50).execute().value
                    await MainActor.run { self.localLeaderboard = localData }
                } catch {
                    print("⚠️ Warning: Loading local leaderboard failed: \(error)")
                }
            } else {
                await MainActor.run { self.localLeaderboard = [] }
            }

            // 4. Load Friends
            if !friendIds.isEmpty {
                do {
                    let friendsData: [CloudProfile] = try await supabase.from("profiles").select().in("id", values: friendIds).execute().value
                    var friendsPlayers = [myProfile]
                    friendsPlayers.append(contentsOf: friendsData)
                    friendsPlayers.sort { $0.xp > $1.xp }
                    await MainActor.run { self.friendsLeaderboard = friendsPlayers }
                } catch {
                    print("⚠️ Warning: Loading friends leaderboard failed: \(error)")
                    // Keep just ourselves if it fails
                    await MainActor.run { self.friendsLeaderboard = [myProfile] }
                }
            } else {
                await MainActor.run { self.friendsLeaderboard = [myProfile] }
            }
        }
    }

    // --- DISCOVERY ---

    func fetchRecommendedPeaks() {
        Task {
            do {
                // 1. Lade alle Berge von Supabase.
                // HINWEIS: Wir lassen die datenbankseitige Sortierung (.order) weg,
                // da Postgres bei CamelCase-Namen (isPrestigePeak) oft abstürzt, wenn man sie nicht in Quotes setzt.
                // Das Limit sichert uns gegen zu große Datenmengen ab.
                let allPeaks: [Mountain] = try await supabase
                    .from("mountains")
                    .select("*, routes:mountain_routes(*)")
                    .limit(50)
                    .execute()
                    .value

                // 2. Sortiere und wähle zufällige Berge für die Anzeige LOKAL aus
                let displayPeaks = Array(allPeaks.shuffled().prefix(10))
                let routeSuggestions = Array(allPeaks.shuffled().prefix(8))

                // 3. Baue die Elemente für das Hero Banner zusammen
                var bannerItems: [HeroBannerItem] = []
                for peak in allPeaks.filter({ $0.isPrestigePeak }).shuffled().prefix(3) {
                    bannerItems.append(HeroBannerItem(
                        title: peak.name,
                        subtitle: "\(peak.elevation)m · \(peak.region)",
                        imageURL: (peak.effectiveImageUrl?.isEmpty == false) ? peak.effectiveImageUrl : nil,
                        badge: "PRESTIGE PEAK",
                        mountain: peak
                    ))
                }
                for peak in allPeaks.filter({ !$0.isPrestigePeak }).shuffled().prefix(3) {
                    bannerItems.append(HeroBannerItem(
                        title: peak.name,
                        subtitle: "\(peak.elevation)m · \(peak.region)",
                        imageURL: (peak.effectiveImageUrl?.isEmpty == false) ? peak.effectiveImageUrl : nil,
                        badge: "RECOMMENDED",
                        mountain: peak
                    ))
                }
                let finalBanner = Array(bannerItems.shuffled().prefix(5))

                // 4. Update der UI auf dem Main-Thread
                self.recommendedPeaks = displayPeaks
                self.suggestedRoutes = routeSuggestions
                self.heroBannerItems = finalBanner
                print("✅ Erfolgreich \(allPeaks.count) Berge von Supabase geladen!")
            } catch {
                // 5. Falls es weiterhin fehlschlägt, loggen wir den exakten Grund in die Konsole
                print("❌ Fehler beim Laden der Peaks von Supabase: \(error)")
                print("💡 Tipp: Wenn dies passiert, weichen die Spalten in Supabase wahrscheinlich vom 'Mountain' Modell ab (z.B. imageUrl vs image_url oder falscher Datentyp).")
            }
        }
    }

    // --- COLLECTIONS ---

    func fetchCollections() {
        Task {
            do {
                let userId = try await supabase.auth.session.user.id
                let results: [TourCollection] = try await supabase
                    .from("collections")
                    .select()
                    .eq("user_id", value: userId)
                    .order("updated_at", ascending: false)
                    .execute()
                    .value
                self.myCollections = results
            } catch {
                print("⚠️ Fetch collections: \(error)")
            }
        }
    }
}
