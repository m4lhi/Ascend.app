import Foundation
import Supabase

// =========================================
// === DATEI: LeaderboardService.swift ===
// === Network layer for leaderboards + friendships ===
// =========================================
//
// Wraps Supabase calls for the leaderboard domain: friendship rows,
// global/local top-50 profile ranking, friendship inserts. Profile
// lookup-by-id (for the friends-list resolution) is delegated to
// ProfileService.fetchProfiles(userIds:). Profile-by-handle (used by
// the add-friend flow) lives in ProfileService too, called from
// LeaderboardViewModel.
//
// Stateless — no @Published, no in-memory cache. Caller (LeaderboardVM)
// holds the resulting arrays in its own observable surface. The Service
// intentionally does not reference AppState or any ViewModel.

final class LeaderboardService {
    static let shared = LeaderboardService()
    private init() {}

    // MARK: - Friendships

    /// Fetch the IDs of every user the given user has befriended.
    func fetchFriendshipIds(userId: UUID) async throws -> [UUID] {
        let rows: [FriendshipRule] = try await supabase
            .from("friendships")
            .select("friend_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.map { $0.friend_id }
    }

    /// Insert a friendship row. Caller should swallow Postgres
    /// unique-violation errors (23505) gracefully when the row already
    /// exists.
    func insertFriendship(userId: UUID, friendId: UUID) async throws {
        struct NewFriendship: Codable { let user_id: UUID; let friend_id: UUID }
        try await supabase
            .from("friendships")
            .insert(NewFriendship(user_id: userId, friend_id: friendId))
            .execute()
    }

    // MARK: - Top boards

    /// Top-N profiles globally, ranked by xp desc.
    func fetchGlobalTop(limit: Int = 50) async throws -> [CloudProfile] {
        try await supabase
            .from("profiles")
            .select()
            .order("xp", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Top-N profiles filtered to the given region, ranked by xp desc.
    func fetchLocalTop(region: String, limit: Int = 50) async throws -> [CloudProfile] {
        try await supabase
            .from("profiles")
            .select()
            .eq("region", value: region)
            .order("xp", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}
