import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: FeedViewModel.swift ===
// === Tour-feed @Published surface ===
// =========================================
//
// Owns the feed state (recentTours, bookmarkedTours, pagination
// signals) and exposes the read/write methods that AppState used to
// host. Delegates all Supabase work to FeedService — never imports
// AppState.
//
// MARK: - Transitional surface (R4 / R5 remove)
//
// appendNewTour(_:) and removeTour(id:) exist so AppState's tour-
// lifecycle methods (addCompletedTour / deleteTour) can mutate the
// feed cache after their own cloud-upload + XP-push work. They move
// into a RecordingViewModel in R4 alongside the LiveRecordView split.

@MainActor
final class FeedViewModel: ObservableObject {
    // MARK: - Published surface

    @Published private(set) var recentTours: [Tour] = []
    @Published private(set) var bookmarkedTours: [Tour] = []
    @Published private(set) var isLoadingMoreFeed: Bool = false
    @Published private(set) var hasMoreFeed: Bool = true

    // MARK: - Pagination state (private)

    private var feedPage: Int = 0
    private let feedPageSize: Int = 10
    private let feedMaxItems: Int = 50

    private let service: FeedService = .shared

    // MARK: - Read API

    /// Fetch the first page. Idempotent unless forceRefresh is set.
    func fetchFeed(forceRefresh: Bool = false) {
        if !forceRefresh && !recentTours.isEmpty { return }
        feedPage = 0
        hasMoreFeed = true
        recentTours = []
        loadFeedPage()
    }

    /// Pagination trigger from infinite-scroll. No-op if already loading
    /// or if we've already hit the cap.
    func loadNextFeedPage() {
        guard !isLoadingMoreFeed && hasMoreFeed && recentTours.count < feedMaxItems else { return }
        loadFeedPage()
    }

    /// Refresh the bookmarked-tours collection from the cloud.
    func fetchBookmarkedTours() {
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let bookmarkIds = try await service.fetchMyBookmarkIds(userId: myId)
                if bookmarkIds.isEmpty {
                    self.bookmarkedTours = []
                    return
                }
                let cloudTours = try await service.fetchTours(ids: bookmarkIds)
                let built = try await buildDisplayTours(from: cloudTours, myId: myId, forceBookmarked: true)
                self.bookmarkedTours = built
            } catch {
                print("❌ FeedViewModel.fetchBookmarkedTours error: \(error)")
            }
        }
    }

    // MARK: - Interactions

    /// Toggle the fist-bump state on a tour. Optimistic local update +
    /// background cloud sync.
    func toggleFistBump(tour: Tour) {
        guard let tourId = tour.cloudId else { return }
        let wasBumped = tour.isFistBumped
        if let idx = recentTours.firstIndex(where: { $0.id == tour.id }) {
            recentTours[idx].isFistBumped.toggle()
            recentTours[idx].fistBumpCount += wasBumped ? -1 : 1
        }
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                if wasBumped {
                    try await service.deleteFistBump(tourId: tourId, userId: myId)
                } else {
                    try await service.insertFistBump(tourId: tourId, userId: myId)
                }
            } catch {
                print("❌ FeedViewModel.toggleFistBump error: \(error)")
            }
        }
    }

    /// Optimistic comment-count bump + background cloud insert.
    func postComment(tour: Tour, body: String) {
        guard let tourId = tour.cloudId else { return }
        if let idx = recentTours.firstIndex(where: { $0.id == tour.id }) {
            recentTours[idx].commentCount += 1
        }
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                try await service.insertComment(tourId: tourId, userId: myId, body: body)
            } catch {
                print("❌ FeedViewModel.postComment error: \(error)")
            }
        }
    }

    /// Load all comments for a tour, denormalized for display.
    func fetchComments(tour: Tour) async -> [CommentDisplay] {
        guard let tourId = tour.cloudId else { return [] }
        do {
            let myId = try await supabase.auth.session.user.id
            let rows = try await service.fetchComments(tourId: tourId)
            let userIds = Array(Set(rows.map { $0.user_id }))
            let profiles = try await service.fetchProfiles(userIds: userIds)
            let profileLookup = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            return rows.compactMap { row -> CommentDisplay? in
                guard let id = row.id, let createdAt = row.created_at else { return nil }
                let profile = profileLookup[row.user_id]
                return CommentDisplay(
                    id: id,
                    userName: profile?.username ?? "Unknown",
                    userHandle: profile?.handle ?? "user",
                    avatarURL: profile?.avatar_url,
                    body: row.body,
                    date: createdAt,
                    isCurrentUser: row.user_id == myId
                )
            }
        } catch {
            print("❌ FeedViewModel.fetchComments error: \(error)")
            return []
        }
    }

    /// Toggle the bookmark state on a tour. Optimistic local update +
    /// background cloud sync + bookmarked-collection refresh.
    func toggleBookmark(tour: Tour) {
        guard let tourId = tour.cloudId else { return }
        let wasBookmarked = tour.isBookmarked
        if let idx = recentTours.firstIndex(where: { $0.id == tour.id }) {
            recentTours[idx].isBookmarked.toggle()
        }
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                if wasBookmarked {
                    try await service.deleteBookmark(tourId: tourId, userId: myId)
                } else {
                    try await service.insertBookmark(tourId: tourId, userId: myId, mountainName: tour.summitName)
                }
                fetchBookmarkedTours()
            } catch {
                print("❌ FeedViewModel.toggleBookmark error: \(error)")
            }
        }
    }

    // MARK: - Tour-lifecycle hooks (transitional)

    /// Insert a freshly-uploaded tour at the top of the feed. Called by
    /// AppState.addCompletedTour after its cloud insert succeeds.
    /// Moves into RecordingViewModel in R4.
    func appendNewTour(_ tour: Tour) {
        recentTours.insert(tour, at: 0)
    }

    /// Remove a tour from the local feed cache. Called by
    /// AppState.deleteTour. Moves into RecordingViewModel in R4.
    func removeTour(id: UUID) {
        recentTours.removeAll { $0.id == id }
    }

    /// Mirror profile changes onto the owner's tours in the feed cache.
    /// Called from EditAccountView.save() after ProfileViewModel updates
    /// the cloud row. Moves into a feed-event subscription in R3 step 4
    /// (LeaderboardViewModel) or later.
    func applyProfileUpdate(userId: UUID, name: String, handle: String, avatarURL: String?) {
        for i in recentTours.indices where recentTours[i].userId == userId {
            recentTours[i].playerName = name
            recentTours[i].playerHandle = handle
            recentTours[i].playerAvatarURL = avatarURL
        }
    }

    // MARK: - Private

    private func loadFeedPage() {
        guard !isLoadingMoreFeed else { return }
        isLoadingMoreFeed = true
        Task {
            do {
                let myId = try await supabase.auth.session.user.id
                let rangeStart = feedPage * feedPageSize
                let rangeEnd = rangeStart + feedPageSize - 1
                let cloudTours = try await service.fetchToursPage(rangeStart: rangeStart, rangeEnd: rangeEnd)
                let pageTours = try await buildDisplayTours(from: cloudTours, myId: myId)

                self.recentTours.append(contentsOf: pageTours)
                self.feedPage += 1
                self.hasMoreFeed = cloudTours.count == self.feedPageSize
                self.isLoadingMoreFeed = false
            } catch {
                print("❌ FeedViewModel.loadFeedPage error: \(error)")
                self.isLoadingMoreFeed = false
            }
        }
    }

    /// Compose display Tour structs from raw CloudTour rows + parallel
    /// social data lookups. forceBookmarked sets isBookmarked = true
    /// (used when the input came from the bookmarked_routes table).
    private func buildDisplayTours(from cloudTours: [CloudTour], myId: UUID, forceBookmarked: Bool = false) async throws -> [Tour] {
        guard !cloudTours.isEmpty else { return [] }
        let tourIds = cloudTours.compactMap { $0.id }
        let userIds = Array(Set(cloudTours.map { $0.user_id }))

        async let profilesTask = service.fetchProfiles(userIds: userIds)
        async let bumpsTask: [CloudFistBump] = (try? await service.fetchFistBumps(tourIds: tourIds)) ?? []
        async let commentCountsTask: [UUID: Int] = (try? await service.fetchCommentCounts(tourIds: tourIds)) ?? [:]
        async let myBookmarksTask: Set<UUID> = forceBookmarked
            ? Set(tourIds)
            : ((try? await service.fetchMyBookmarkIds(userId: myId, tourIds: tourIds)) ?? [])

        let profiles = (try? await profilesTask) ?? []
        let bumps = await bumpsTask
        let commentCounts = await commentCountsTask
        let myBookmarks = await myBookmarksTask

        let profileLookup = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        var bumpsByTour: [UUID: [CloudFistBump]] = [:]
        for bump in bumps { bumpsByTour[bump.tour_id, default: []].append(bump) }

        let pauseDecoder = JSONDecoder()
        pauseDecoder.dateDecodingStrategy = .iso8601

        var result: [Tour] = []
        for tour in cloudTours {
            guard let player = profileLookup[tour.user_id] else { continue }

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
            let routeLocs = tour.route_polyline.flatMap { RouteEncoder.decodeWithAltitude($0) } ?? []

            result.append(Tour(
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
                commentCount: tour.id != nil ? commentCounts[tour.id!] ?? 0 : 0,
                isBookmarked: tour.id != nil ? myBookmarks.contains(tour.id!) : false,
                routeCoordinates: routeCoords,
                routeLocations: routeLocs
            ))
        }
        return result
    }
}
