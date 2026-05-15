import Foundation

// =========================================
// === DATEI: FriendshipRule.swift ===
// === friendships row projection ===
// =========================================
//
// Minimal projection of the Supabase `friendships` row used by the
// leaderboard fetch: we only need the friend_id column to build
// the friends list. Extracted from AppState so LeaderboardService /
// LeaderboardViewModel can reference it without pulling AppState.

struct FriendshipRule: Codable {
    let friend_id: UUID
}
