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
    let user_id: UUID
    let name: String
    let elevation: Int
    let date: Date
    let difficulty: String
    let notes: String
    let duration_seconds: Int?
    let distance_km: Double?
}

struct FriendshipRule: Codable {
    let friend_id: UUID
}

struct Tour: Identifiable {
    let id = UUID()
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
                try await supabase.storage.from("avatars").upload(path: path, file: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
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
    
    // Holt alle Touren für den Feed
    func fetchFeed() {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let myFriendships: [FriendshipRule] = try await supabase.from("friendships").select("friend_id").eq("user_id", value: myId).execute().value
                
                var relevantIds = myFriendships.map { $0.friend_id }
                relevantIds.append(myId)
                
                let profiles: [CloudProfile] = try await supabase.from("profiles").select().in("id", value: relevantIds).execute().value
                let cloudTours: [CloudTour] = try await supabase.from("tours").select().in("user_id", value: relevantIds).execute().value
                
                var newFeed: [Tour] = []
                for tour in cloudTours {
                    if let player = profiles.first(where: { $0.id == tour.user_id }) {
                        let feedTour = Tour(
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
                            isCurrentUser: player.id == myId
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
    func addCompletedTour(summit: String, comment: String, elevation: Int, duration: TimeInterval, distance: Double, xp: Int) {
        self.currentXP += xp
        self.currentLevel = (self.currentXP / 1000) + 1
        
        uploadProfileToCloud()
        fetchLeaderboard()
        
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let newCloudTour = CloudTour(
                    user_id: myId,
                    name: summit,
                    elevation: elevation,
                    date: Date(),
                    difficulty: "Medium",
                    notes: comment,
                    duration_seconds: Int(duration),
                    distance_km: distance
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
                let myId = try await supabase.auth.session.user.id
                try await supabase.from("tours").delete().eq("user_id", value: myId).eq("name", value: tour.summitName).execute()
            } catch { print("❌ Fehler beim Löschen der Tour: \(error)") }
        }
    }

    // --- SOCIAL FUNKTIONEN ---
    
    // Fügt einen Freund anhand des Handles hinzu
    func addFriend(handleToSearch: String) {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let friendProfiles: [CloudProfile] = try await supabase.from("profiles").select().ilike("handle", value: handleToSearch).execute().value
                
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
                    let friendsData: [CloudProfile] = try await supabase.from("profiles").select().in("id", value: friendIds).execute().value
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
}
