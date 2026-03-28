import Foundation
import SwiftUI
import Combine
import Supabase

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
}

// HIER IST DAS ABZEICHEN, DAS XCODE VERMISST HAT:
struct ConquestBadge: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let isUnlocked: Bool
    let isGold: Bool
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
    let playerName: String
    let playerHandle: String
    let playerAvatarURL: String?
    let date: Date
    let summitName: String
    let storyComment: String
    let elevationGainMeters: Int
    let durationSeconds: TimeInterval
    let distanceKilometers: Double
    let xpGained: Int
    let isCurrentUser: Bool
    var pauseCount: Int = 0
    var totalPauseDuration: TimeInterval = 0
    var fistBumpCount: Int = 0
    var isFistBumped: Bool = false
    var commentCount: Int = 0
    var isBookmarked: Bool = false
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
    
    // Fortschritt
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    
    // Feeds & Leaderboards
    @Published var recentTours: [Tour] = []
    @Published var friendsLeaderboard: [CloudProfile] = []
    @Published var globalLeaderboard: [CloudProfile] = []
    @Published var localLeaderboard: [CloudProfile] = []

    // Discovery
    @Published var recommendedPeaks: [Mountain] = []

    var currentLevelProgressXP: Int { currentXP % 1000 }
    var xpNeededForNextLevel: Int { 1000 }
    
    // Dummy-Abzeichen für das UI
    @Published var badges: [ConquestBadge] = [
        ConquestBadge(title: "First Peak", icon: "mountain.2.fill", isUnlocked: true, isGold: false),
        ConquestBadge(title: "10k Elevation", icon: "arrow.up.right.circle.fill", isUnlocked: false, isGold: false),
        ConquestBadge(title: "Elite Alpinist", icon: "crown.fill", isUnlocked: false, isGold: true)
    ]
    
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
                
                fetchLeaderboard()
                fetchFeed()
            } catch {
                if self.userHandle == "climber" {
                    self.userHandle = "climber_\(Int.random(in: 1000...9999))"
                }
                uploadProfileToCloud()
            }
        }
    }
    
    // Speichert einfache Änderungen wie XP
    func uploadProfileToCloud() {
        Task {
            do {
                let session = try await supabase.auth.session
                let updatedProfile = CloudProfile(id: session.user.id, username: self.userName, handle: self.userHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: self.avatarURL, region: self.userRegion)
                try await supabase.from("profiles").upsert(updatedProfile).execute()
                fetchLeaderboard()
            } catch { print("❌ Fehler beim Speichern: \(error)") }
        }
    }
    
    // Speichert Profil-Einstellungen aus dem Edit-Fenster
    func updateProfileSettings(newName: String, newHandle: String, newRegion: String, newSports: [String]) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let updatedProfile = CloudProfile(id: session.user.id, username: newName, handle: newHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: self.avatarURL, region: newRegion)
            try await supabase.from("profiles").upsert(updatedProfile).execute()
            
            self.userName = newName; self.userHandle = newHandle; self.userRegion = newRegion; self.selectedSports = newSports
            fetchLeaderboard()
            return true
        } catch { return false }
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
                
                let updatedProfile = CloudProfile(id: userId, username: self.userName, handle: self.userHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: cacheBusterURL, region: self.userRegion)
                try await supabase.from("profiles").upsert(updatedProfile).execute()
                
                fetchLeaderboard()
                fetchFeed()
            } catch { print("❌ Fehler beim Bild-Upload: \(error)") }
        }
    }

    // --- TOUR FUNKTIONEN ---
    
    // Holt alle Touren für den Feed (mit Social-Daten)
    func fetchFeed() {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let myFriendships: [FriendshipRule] = try await supabase.from("friendships").select("friend_id").eq("user_id", value: myId).execute().value

                var relevantIds = myFriendships.map { $0.friend_id }
                relevantIds.append(myId)

                let profiles: [CloudProfile] = try await supabase.from("profiles").select().in("id", values: relevantIds).execute().value
                let cloudTours: [CloudTour] = try await supabase.from("tours").select().in("user_id", values: relevantIds).execute().value

                // Alle tour IDs sammeln für Social-Queries
                let tourIds = cloudTours.compactMap { $0.id }

                // Fist bumps, comments, bookmarks in parallel laden
                var allBumps: [CloudFistBump] = []
                var allCommentCounts: [UUID: Int] = [:]
                var myBookmarks: Set<UUID> = []

                if !tourIds.isEmpty {
                    allBumps = (try? await supabase.from("fist_bumps").select().in("tour_id", values: tourIds).execute().value) ?? []

                    struct CommentRow: Codable { let tour_id: UUID }
                    let commentRows: [CommentRow] = (try? await supabase.from("comments").select("tour_id").in("tour_id", values: tourIds).execute().value) ?? []
                    for row in commentRows {
                        allCommentCounts[row.tour_id, default: 0] += 1
                    }

                    struct BookmarkRow: Codable { let tour_id: UUID }
                    let bookmarkRows: [BookmarkRow] = (try? await supabase.from("bookmarked_routes").select("tour_id").eq("user_id", value: myId).in("tour_id", values: tourIds).execute().value) ?? []
                    myBookmarks = Set(bookmarkRows.map { $0.tour_id })
                }

                var newFeed: [Tour] = []
                for tour in cloudTours {
                    if let player = profiles.first(where: { $0.id == tour.user_id }) {
                        var parsedPauseCount = 0
                        var parsedPauseDuration: TimeInterval = 0
                        if let json = tour.pauses, let data = json.data(using: .utf8) {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            if let entries = try? decoder.decode([PauseEntry].self, from: data) {
                                parsedPauseCount = entries.count
                                parsedPauseDuration = entries.reduce(0) { $0 + $1.duration }
                            }
                        }

                        let tourBumps = tour.id != nil ? allBumps.filter { $0.tour_id == tour.id! } : []

                        let feedTour = Tour(
                            cloudId: tour.id,
                            playerName: player.username,
                            playerHandle: player.handle,
                            playerAvatarURL: player.avatar_url,
                            date: tour.date,
                            summitName: tour.name,
                            storyComment: tour.notes,
                            elevationGainMeters: tour.elevation,
                            durationSeconds: TimeInterval(tour.duration_seconds ?? 0),
                            distanceKilometers: tour.distance_km ?? 0.0,
                            xpGained: 100 + tour.elevation,
                            isCurrentUser: player.id == myId,
                            pauseCount: parsedPauseCount,
                            totalPauseDuration: parsedPauseDuration,
                            fistBumpCount: tourBumps.count,
                            isFistBumped: tourBumps.contains { $0.user_id == myId },
                            commentCount: tour.id != nil ? allCommentCounts[tour.id!] ?? 0 : 0,
                            isBookmarked: tour.id != nil ? myBookmarks.contains(tour.id!) : false
                        )
                        newFeed.append(feedTour)
                    }
                }
                newFeed.sort { $0.date > $1.date }
                await MainActor.run { self.recentTours = newFeed }
            } catch { print("❌ Fehler beim Feed laden: \(error)") }
        }
    }

    // Fügt eine neue Tour hinzu (vom Tracker)
    func addCompletedTour(summit: String, comment: String, elevation: Int, duration: TimeInterval, distance: Double, xp: Int, pauses: [PauseEntry] = []) {
        self.currentXP += xp
        self.currentLevel = (self.currentXP / 1000) + 1

        uploadProfileToCloud()
        fetchLeaderboard()

        Task {
            do {
                let myId = try await supabase.auth.session.user.id

                var pausesJSON: String? = nil
                if !pauses.isEmpty {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    if let data = try? encoder.encode(pauses) {
                        pausesJSON = String(data: data, encoding: .utf8)
                    }
                }

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
                    pauses: pausesJSON
                )
                try await supabase.from("tours").insert(newCloudTour).execute()
                fetchFeed()
            } catch { print("❌ Fehler beim Tour hochladen: \(error)") }
        }
    }

    // Löscht eine Tour
    func deleteTour(tour: Tour) {
        self.currentXP = max(0, self.currentXP - tour.xpGained)
        self.currentLevel = max(1, (self.currentXP / 1000) + 1)
        self.recentTours.removeAll { $0.id == tour.id }
        uploadProfileToCloud()
        fetchLeaderboard()

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
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                if tour.isFistBumped {
                    try await supabase.from("fist_bumps").delete().eq("tour_id", value: tourId).eq("user_id", value: myId).execute()
                } else {
                    try await supabase.from("fist_bumps").insert(CloudFistBump(tour_id: tourId, user_id: myId)).execute()
                }
                fetchFeed()
            } catch { print("❌ Fehler beim Fist Bump: \(error)") }
        }
    }

    // Kommentar posten
    func postComment(tour: Tour, body: String) {
        guard let tourId = tour.cloudId, !body.isEmpty else { return }
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let comment = CloudComment(id: nil, tour_id: tourId, user_id: myId, body: body, created_at: nil)
                try await supabase.from("comments").insert(comment).execute()
                fetchFeed()
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
            let profiles: [CloudProfile] = try await supabase.from("profiles").select().in("id", values: userIds).execute().value

            return rows.map { row in
                let profile = profiles.first { $0.id == row.user_id }
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
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                if tour.isBookmarked {
                    try await supabase.from("bookmarked_routes").delete().eq("tour_id", value: tourId).eq("user_id", value: myId).execute()
                } else {
                    try await supabase.from("bookmarked_routes").insert(CloudBookmark(tour_id: tourId, user_id: myId, mountain_name: tour.summitName)).execute()
                }
                fetchFeed()
            } catch { print("❌ Fehler beim Bookmark: \(error)") }
        }
    }

    // Fügt einen Freund anhand des Handles hinzu
    func addFriend(handleToSearch: String) {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let friendProfiles: [CloudProfile] = try await supabase.from("profiles").select().ilike("handle", pattern: handleToSearch).execute().value
                
                guard let friend = friendProfiles.first, friend.id != myId else { return }
                
                struct NewFriendship: Codable { let user_id: UUID; let friend_id: UUID }
                try await supabase.from("friendships").insert(NewFriendship(user_id: myId, friend_id: friend.id)).execute()
                
                fetchLeaderboard()
                fetchFeed()
            } catch { print("❌ Fehler beim Adden: \(error)") }
        }
    }
    
    // Holt die drei Leaderboard-Listen
    func fetchLeaderboard() {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let myProfile = CloudProfile(id: myId, username: self.userName, handle: self.userHandle, xp: self.currentXP, level: self.currentLevel, avatar_url: self.avatarURL, region: self.userRegion)
                
                // 1. FRIENDS
                let myFriendships: [FriendshipRule] = try await supabase.from("friendships").select("friend_id").eq("user_id", value: myId).execute().value
                let friendIds = myFriendships.map { $0.friend_id }
                var friendsPlayers: [CloudProfile] = [myProfile]
                if !friendIds.isEmpty {
                    let friendsData: [CloudProfile] = try await supabase.from("profiles").select().in("id", values: friendIds).execute().value
                    friendsPlayers.append(contentsOf: friendsData)
                }
                friendsPlayers.sort { $0.xp > $1.xp }
                
                // 2. GLOBAL
                let globalData: [CloudProfile] = try await supabase.from("profiles").select().order("xp", ascending: false).limit(50).execute().value
                
                // 3. LOCAL
                let localData: [CloudProfile]
                if !self.userRegion.isEmpty {
                    localData = try await supabase.from("profiles").select().eq("region", value: self.userRegion).order("xp", ascending: false).limit(50).execute().value
                } else {
                    localData = []
                }
                
                await MainActor.run {
                    self.friendsLeaderboard = friendsPlayers
                    self.globalLeaderboard = globalData
                    self.localLeaderboard = localData
                }
            } catch { print("❌ Fehler beim Leaderboard laden: \(error)") }
        }
    }

    // --- DISCOVERY ---

    func fetchRecommendedPeaks() {
        Task {
            do {
                let peaks: [Mountain] = try await supabase
                    .from("mountains")
                    .select()
                    .order("isPrestigePeak", ascending: false)
                    .order("elevation", ascending: false)
                    .limit(10)
                    .execute()
                    .value
                await MainActor.run { self.recommendedPeaks = peaks }
            } catch {
                print("❌ Fehler beim Laden der empfohlenen Peaks: \(error)")
            }
        }
    }
}
