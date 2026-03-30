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
    let photo_url: String?
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
    var photoURL: String? = nil
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

// --- HERO BANNER MODEL ---

struct HeroBannerItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: String?
    let badge: String?       // e.g. "PRESTIGE PEAK", "TRENDING", "COMMUNITY"
    let mountain: Mountain?  // nil for community highlights
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
    
    // Ascend Progress
    @Published var ascendProfile: AscendProfile? = nil

    
    // Feeds & Leaderboards
    @Published var recentTours: [Tour] = []
    @Published var friendsLeaderboard: [CloudProfile] = []
    @Published var globalLeaderboard: [CloudProfile] = []
    @Published var localLeaderboard: [CloudProfile] = []

    // Discovery
    @Published var recommendedPeaks: [Mountain] = []
    @Published var heroBannerItems: [HeroBannerItem] = []
    @Published var suggestedRoutes: [Mountain] = []

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
                fetchAscendProfile()
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
                
                await MainActor.run {
                    self.ascendProfile = result
                }
            } catch {
                print("⚠️ Fetch Ascend Profile: \(error)")
                // Create dummy or insert if not exists
                await MainActor.run {
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
                }
            }
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

                let profiles: [CloudProfile] = try await supabase.from("profiles").select().in("id", values: relevantIds).execute().value

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

                var pageTours: [Tour] = []
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
                            photoURL: tour.photo_url,
                            pauseCount: parsedPauseCount,
                            totalPauseDuration: parsedPauseDuration,
                            fistBumpCount: tourBumps.count,
                            isFistBumped: tourBumps.contains { $0.user_id == myId },
                            commentCount: tour.id != nil ? allCommentCounts[tour.id!] ?? 0 : 0,
                            isBookmarked: tour.id != nil ? myBookmarks.contains(tour.id!) : false
                        )
                        pageTours.append(feedTour)
                    }
                }

                print("📡 Feed loaded: \(cloudTours.count) cloud tours → \(pageTours.count) display tours (profiles matched: \(profiles.count))")
                await MainActor.run {
                    self.recentTours.append(contentsOf: pageTours)
                    self.feedPage += 1
                    self.hasMoreFeed = cloudTours.count == self.feedPageSize
                    self.isLoadingMoreFeed = false
                }
            } catch {
                print("❌ Fehler beim Feed laden: \(error)")
                await MainActor.run { self.isLoadingMoreFeed = false }
            }
        }
    }

    // Fügt eine neue Tour hinzu (vom Tracker)
    func addCompletedTour(summit: String, comment: String, elevation: Int, duration: TimeInterval, distance: Double, xp: Int, pauses: [PauseEntry] = [], photoData: Data? = nil) {
        self.currentXP += xp
        self.currentLevel = (self.currentXP / 1000) + 1

        uploadProfileToCloud()
        fetchLeaderboard()

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

            // Resize photo early (before network calls) so it's ready
            var compressedPhoto: Data? = nil
            if let photoData, let uiImage = UIImage(data: photoData) {
                let maxDim: CGFloat = 800
                let scale = min(maxDim / max(uiImage.size.width, uiImage.size.height), 1.0)
                let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
                compressedPhoto = resized.jpegData(compressionQuality: 0.6)
                print("📸 Photo prepared (\((compressedPhoto?.count ?? 0) / 1024)KB)")
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
                photo_url: photoURL
            )

            for attempt in 1...3 {
                do {
                    try await supabase.from("tours").insert(newCloudTour).execute()
                    print("✅ Tour erfolgreich hochgeladen: \(summit) (attempt \(attempt))")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run { fetchFeed() }
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
                // 1. Lade alle Berge von Supabase.
                // HINWEIS: Wir lassen die datenbankseitige Sortierung (.order) weg,
                // da Postgres bei CamelCase-Namen (isPrestigePeak) oft abstürzt, wenn man sie nicht in Quotes setzt.
                // Das Limit sichert uns gegen zu große Datenmengen ab.
                let allPeaks: [Mountain] = try await supabase
                    .from("mountains")
                    .select()
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
                        imageURL: (peak.imageUrl?.isEmpty == false) ? peak.imageUrl : nil,
                        badge: "PRESTIGE PEAK",
                        mountain: peak
                    ))
                }
                for peak in allPeaks.filter({ !$0.isPrestigePeak }).shuffled().prefix(3) {
                    bannerItems.append(HeroBannerItem(
                        title: peak.name,
                        subtitle: "\(peak.elevation)m · \(peak.region)",
                        imageURL: (peak.imageUrl?.isEmpty == false) ? peak.imageUrl : nil,
                        badge: "RECOMMENDED",
                        mountain: peak
                    ))
                }
                let finalBanner = Array(bannerItems.shuffled().prefix(5))

                // 4. Update der UI auf dem Main-Thread
                await MainActor.run {
                    self.recommendedPeaks = displayPeaks
                    self.suggestedRoutes = routeSuggestions
                    self.heroBannerItems = finalBanner
                    print("✅ Erfolgreich \(allPeaks.count) Berge von Supabase geladen!")
                }
            } catch {
                // 5. Falls es weiterhin fehlschlägt, loggen wir den exakten Grund in die Konsole
                print("❌ Fehler beim Laden der Peaks von Supabase: \(error)")
                print("💡 Tipp: Wenn dies passiert, weichen die Spalten in Supabase wahrscheinlich vom 'Mountain' Modell ab (z.B. imageUrl vs image_url oder falscher Datentyp).")
            }
        }
    }
}
