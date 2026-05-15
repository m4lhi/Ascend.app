import Foundation
import Supabase

// =========================================
// === DATEI: FeedService.swift ===
// === Network layer for the social feed ===
// =========================================
//
// Stateless wrappers around the Supabase calls the feed domain needs:
// tours (read/insert/delete), tour authors (profiles enrichment),
// fist bumps, comments, bookmarks.
//
// Each method does one Supabase request and returns raw row data —
// no Tour-building, no orchestration. FeedViewModel composes the
// display Tour from these primitives.

final class FeedService {
    static let shared = FeedService()
    private init() {}

    // MARK: - Tours

    /// Fetch a page of recent tours, ordered by date desc.
    func fetchToursPage(rangeStart: Int, rangeEnd: Int) async throws -> [CloudTour] {
        try await supabase
            .from("tours")
            .select()
            .order("date", ascending: false)
            .range(from: rangeStart, to: rangeEnd)
            .execute()
            .value
    }

    /// Fetch tours by IDs (used for bookmarked-tour enrichment).
    func fetchTours(ids: [UUID]) async throws -> [CloudTour] {
        try await supabase
            .from("tours")
            .select()
            .in("id", values: ids)
            .order("date", ascending: false)
            .execute()
            .value
    }

    /// Insert a new tour row, return the inserted row (with id assigned).
    func insertTour(_ tour: CloudTour) async throws -> CloudTour {
        try await supabase
            .from("tours")
            .insert(tour)
            .select()
            .single()
            .execute()
            .value
    }

    /// Delete a tour by its cloud id.
    func deleteTour(id: UUID) async throws {
        try await supabase
            .from("tours")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Delete a tour matching user_id + name (fallback when no cloudId).
    func deleteTour(userId: UUID, name: String) async throws {
        try await supabase
            .from("tours")
            .delete()
            .eq("user_id", value: userId)
            .eq("name", value: name)
            .execute()
    }

    // MARK: - Profile enrichment

    /// Fetch the public profile rows for a set of user IDs (denormalized
    /// columns only — username, handle, avatar_url, xp, level, region).
    func fetchProfiles(userIds: [UUID]) async throws -> [CloudProfile] {
        try await supabase
            .from("profiles")
            .select("id,username,handle,avatar_url,xp,level,region")
            .in("id", values: userIds)
            .execute()
            .value
    }

    // MARK: - Fist Bumps

    func fetchFistBumps(tourIds: [UUID]) async throws -> [CloudFistBump] {
        try await supabase
            .from("fist_bumps")
            .select()
            .in("tour_id", values: tourIds)
            .execute()
            .value
    }

    func insertFistBump(tourId: UUID, userId: UUID) async throws {
        try await supabase
            .from("fist_bumps")
            .insert(CloudFistBump(tour_id: tourId, user_id: userId))
            .execute()
    }

    func deleteFistBump(tourId: UUID, userId: UUID) async throws {
        try await supabase
            .from("fist_bumps")
            .delete()
            .eq("tour_id", value: tourId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Comments

    private struct CommentRow: Codable { let tour_id: UUID }

    /// Count comments per tour for a set of tour IDs.
    func fetchCommentCounts(tourIds: [UUID]) async throws -> [UUID: Int] {
        let rows: [CommentRow] = try await supabase
            .from("comments")
            .select("tour_id")
            .in("tour_id", values: tourIds)
            .execute()
            .value
        var counts: [UUID: Int] = [:]
        for row in rows { counts[row.tour_id, default: 0] += 1 }
        return counts
    }

    /// Fetch full comment rows for a single tour, oldest first.
    func fetchComments(tourId: UUID) async throws -> [CloudComment] {
        try await supabase
            .from("comments")
            .select()
            .eq("tour_id", value: tourId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func insertComment(tourId: UUID, userId: UUID, body: String) async throws {
        let comment = CloudComment(id: nil, tour_id: tourId, user_id: userId, body: body, created_at: nil)
        try await supabase
            .from("comments")
            .insert(comment)
            .execute()
    }

    // MARK: - Bookmarks

    private struct BookmarkRow: Codable { let tour_id: UUID }

    /// Fetch this user's bookmarked tour IDs.
    func fetchMyBookmarkIds(userId: UUID) async throws -> [UUID] {
        let rows: [BookmarkRow] = try await supabase
            .from("bookmarked_routes")
            .select("tour_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.map { $0.tour_id }
    }

    /// Fetch bookmark IDs for the given user filtered to a tour set.
    func fetchMyBookmarkIds(userId: UUID, tourIds: [UUID]) async throws -> Set<UUID> {
        let rows: [BookmarkRow] = try await supabase
            .from("bookmarked_routes")
            .select("tour_id")
            .eq("user_id", value: userId)
            .in("tour_id", values: tourIds)
            .execute()
            .value
        return Set(rows.map { $0.tour_id })
    }

    func insertBookmark(tourId: UUID, userId: UUID, mountainName: String) async throws {
        try await supabase
            .from("bookmarked_routes")
            .insert(CloudBookmark(tour_id: tourId, user_id: userId, mountain_name: mountainName))
            .execute()
    }

    func deleteBookmark(tourId: UUID, userId: UUID) async throws {
        try await supabase
            .from("bookmarked_routes")
            .delete()
            .eq("tour_id", value: tourId)
            .eq("user_id", value: userId)
            .execute()
    }
}
