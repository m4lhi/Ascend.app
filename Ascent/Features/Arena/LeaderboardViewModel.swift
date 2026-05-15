import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: LeaderboardViewModel.swift ===
// === Leaderboard @Published surface ===
// =========================================
//
// Owns the three leaderboard arrays (friends, global, local) and the
// friend-add flow. Delegates network work to LeaderboardService and
// ProfileService.
//
// Cross-VM dependencies:
// * profileVM (weak): used to build the user's CloudProfile snapshot
//   for the friends leaderboard (region also picks the local board).
// * feedVM (weak): addFriend triggers a feed refresh after the
//   friendship inserts, so the new friend's tours show up.
// * appState (weak, TEMP): currentXP / currentLevel for the myProfile
//   snapshot until R5 moves those into ProgressViewModel.

@MainActor
final class LeaderboardViewModel: ObservableObject {
    // MARK: - Published surface

    @Published private(set) var friendsLeaderboard: [CloudProfile] = []
    @Published private(set) var globalLeaderboard: [CloudProfile] = []
    @Published private(set) var localLeaderboard: [CloudProfile] = []

    // MARK: - Cross-VM refs

    weak var profileVM: ProfileViewModel?
    weak var feedVM: FeedViewModel?

    // TEMP: weak ref to AppState for currentXP/currentLevel in myProfile build.
    // Remove when ProgressVM exists (R5).
    weak var appState: AppState?

    private let service: LeaderboardService = .shared
    private let profileService: ProfileService = .shared

    // MARK: - Read

    /// Fetch all three boards (global, local, friends) in sequence.
    /// Error-tolerant — partial failures leave the other boards intact.
    func fetchLeaderboard() {
        Task {
            let myId: UUID
            do {
                myId = try await supabase.auth.session.user.id
            } catch {
                print("❌ Fetch Leaderboard failed: no active session.")
                return
            }

            let myProfile = CloudProfile(
                id: myId,
                username: profileVM?.userName ?? "",
                handle: profileVM?.userHandle ?? "",
                xp: appState?.currentXP ?? 0,
                level: appState?.currentLevel ?? 1,
                avatar_url: profileVM?.avatarURL,
                region: profileVM?.userRegion ?? ""
            )
            let region = profileVM?.userRegion ?? ""

            // 1. Friendships
            var friendIds: [UUID] = []
            do {
                friendIds = try await service.fetchFriendshipIds(userId: myId)
            } catch {
                print("⚠️ Warning: Fetching friendships failed: \(error)")
            }

            // 2. Global
            do {
                let global = try await service.fetchGlobalTop()
                self.globalLeaderboard = global
            } catch {
                print("⚠️ Warning: Loading global leaderboard failed: \(error)")
            }

            // 3. Local
            if !region.isEmpty {
                do {
                    let local = try await service.fetchLocalTop(region: region)
                    self.localLeaderboard = local
                } catch {
                    print("⚠️ Warning: Loading local leaderboard failed: \(error)")
                }
            } else {
                self.localLeaderboard = []
            }

            // 4. Friends list (resolve IDs → profiles, prepend self, sort xp desc)
            if !friendIds.isEmpty {
                do {
                    let friends = try await profileService.fetchProfiles(userIds: friendIds)
                    var friendsPlayers = [myProfile]
                    friendsPlayers.append(contentsOf: friends)
                    friendsPlayers.sort { $0.xp > $1.xp }
                    self.friendsLeaderboard = friendsPlayers
                } catch {
                    print("⚠️ Warning: Loading friends leaderboard failed: \(error)")
                    self.friendsLeaderboard = [myProfile]
                }
            } else {
                self.friendsLeaderboard = [myProfile]
            }
        }
    }

    // MARK: - Write

    /// Look up a profile by handle and insert a friendship row. On
    /// success refreshes the leaderboard and the feed (new friend's
    /// tours need to appear).
    func addFriend(handleToSearch: String) {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let candidates = try await profileService.fetchProfilesByHandle(handleToSearch)

                guard let friend = candidates.first, friend.id != myId else { return }

                // Client-side dedup
                let alreadyFriends = self.friendsLeaderboard.contains { $0.id == friend.id }
                if alreadyFriends { return }

                do {
                    try await service.insertFriendship(userId: myId, friendId: friend.id)
                } catch {
                    // Swallow unique-constraint races (Postgres 23505)
                    let errStr = String(describing: error)
                    if !errStr.contains("23505") {
                        print("❌ Fehler beim Einfügen: \(error)")
                    } else {
                        print("ℹ️ Friendship already exists in DB.")
                    }
                }

                fetchLeaderboard()
                feedVM?.fetchFeed(forceRefresh: true)
            } catch {
                print("❌ Fehler in addFriend: \(error)")
            }
        }
    }
}
