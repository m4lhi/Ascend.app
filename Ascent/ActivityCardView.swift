import SwiftUI
import MapKit

// =========================================
// === DATEI: ActivityCardView.swift ===
// === Komoot-Style Social Feed Card ===
// =========================================

struct ActivityCardView: View {
    @EnvironmentObject var appState: AppState
    let tour: Tour

    @State private var showComments = false
    @State private var showFullImage = false
    @State private var showActivityDetail = false

    // Micro-animation state
    @State private var fistBumpScale: CGFloat = 1.0
    @State private var fistBumpPulse: Bool = false
    @State private var bookmarkScale: CGFloat = 1.0
    @State private var commentScale: CGFloat = 1.0
    @State private var shareScale: CGFloat = 1.0
    @State private var fistBumpTrigger: Int = 0
    @State private var bookmarkTrigger: Int = 0

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d. MMMM yyyy"
        return f
    }()

    var formattedDuration: String {
        Self.durationFormatter.string(from: tour.durationSeconds) ?? "0m"
    }
    var timeAgo: String {
        Self.relativeFormatter.string(for: tour.date) ?? "just now"
    }
    var formattedDate: String {
        Self.dateFormatter.string(from: tour.date)
    }

    private let accent = DesignSystem.Colors.accent

    // Does this card have any visual media?
    private var validPhotoURL: URL? {
        guard let urlString = tour.photoURL, !urlString.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(string: urlString)
    }
    private var hasPhoto: Bool { validPhotoURL != nil }
    private var hasRoute: Bool { !tour.routeCoordinates.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ========== 1. USER HEADER ==========
            userHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // ========== 2. ACTIVITY TYPE BANNER ==========
            activityBanner
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // ========== 3. MEDIA SECTION (Route Map + Photo Carousel) ==========
            mediaBlock
                .frame(height: 240)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    showActivityDetail = true
                }
                .fullScreenCover(isPresented: $showActivityDetail) {
                    ActivityDetailView(tour: tour)
                }

            // ========== 4. STORY / DESCRIPTION ==========
            if !tour.storyComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(tour.storyComment)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            // ========== 5. STATS GRID (Komoot-style) ==========
            statsGrid
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // ========== 6. SOCIAL BAR ==========
            socialBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .sheet(isPresented: $showComments) {
            CommentSheetView(tour: tour)
                .presentationDetents([.medium, .large])
                .preferredColorScheme(.light)
        }
    }

    @State private var showPublicProfile = false

    // MARK: - User Header
    private var userHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: { showPublicProfile = true }) {
                HStack(alignment: .center, spacing: 10) {
                    // Avatar
                    Group {
                        if let urlString = tour.playerAvatarURL, let url = URL(string: urlString) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.2))
                            }
                        } else {
                            Circle()
                                .fill(LinearGradient(colors: [accent.opacity(0.4), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(
                                    Text(String(tour.playerName.prefix(1)))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    Text(tour.playerName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            if tour.isCurrentUser {
                Menu {
                    Button(role: .destructive, action: {
                        appState.deleteTour(tour: tour)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
        }
        .sheet(isPresented: $showPublicProfile) {
            let totalUserXP = appState.friendsLeaderboard.first(where: { $0.id == tour.userId })?.xp ??
                              appState.globalLeaderboard.first(where: { $0.id == tour.userId })?.xp ??
                              0
            
            PublicProfileView(
                userId: tour.userId,
                userName: tour.playerName,
                userHandle: tour.playerHandle,
                avatarURL: tour.playerAvatarURL,
                xp: totalUserXP
            )
            .presentationDetents([.fraction(0.85), .large])
            .preferredColorScheme(.light)
            .environmentObject(appState)
        }
    }

    // MARK: - Activity Banner (summit + type info like Komoot)
    private var activityBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Activity type tag
            HStack(spacing: 6) {
                Image(systemName: "figure.hiking")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent)
                Text("Hiking")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Text("·")
                    .foregroundColor(.secondary)
                Text(formattedDate)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // Summit name as main title
            HStack(spacing: 6) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.7))
                Text(tour.summitName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Unified Media Block
    @ViewBuilder
    private var mediaBlock: some View {
        if hasPhoto && hasRoute {
            TabView {
                tourPhoto
                    .tag(0)
                RouteMapPreview(coordinates: tour.routeCoordinates)
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        } else if hasPhoto {
            tourPhoto
        } else if hasRoute {
            RouteMapPreview(coordinates: tour.routeCoordinates)
        } else {
            defaultPlaceholder
        }
    }

    // MARK: - Tour Photo
    @ViewBuilder
    private var tourPhoto: some View {
        if let url = validPhotoURL {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(ProgressView().tint(.gray))
            }
        }
    }

    // MARK: - Default Placeholder
    private var defaultPlaceholder: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.15, green: 0.2, blue: 0.25), Color(red: 0.05, green: 0.1, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
                Text("No media captured")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats Grid (Komoot-style 3-column)
    private var statsGrid: some View {
        HStack(spacing: 0) {
            StatCell(label: "Distance", value: tour.distanceKilometers > 0 ? String(format: "%.1f km", tour.distanceKilometers) : "—")

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 1, height: 32)

            StatCell(label: "Elevation", value: "+\(tour.elevationGainMeters) m")

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 1, height: 32)

            StatCell(label: "Duration", value: formattedDuration)

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 1, height: 32)

            // XP earned
            VStack(spacing: 2) {
                Text("+\(tour.xpGained)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                Text("XP")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(accent.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(Color(white: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Social Bar
    private var socialBar: some View {
        VStack(spacing: 8) {
            // Like count text (like Komoot: "Max and 3 others gave kudos")
            if tour.fistBumpCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 10))
                        .foregroundColor(accent)
                    Text("\(tour.fistBumpCount) fist bump\(tour.fistBumpCount == 1 ? "" : "s")")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                    if tour.commentCount > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text("\(tour.commentCount) comment\(tour.commentCount == 1 ? "" : "s")")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 0) {
                // Fist Bump — pop + ring pulse + symbol bounce
                Button(action: {
                    HapticManager.shared.light()
                    let wasBumped = tour.isFistBumped
                    appState.toggleFistBump(tour: tour)
                    fistBumpTrigger += 1
                    // Pop scale
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.4)) {
                        fistBumpScale = wasBumped ? 0.82 : 1.35
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                            fistBumpScale = 1.0
                        }
                    }
                    // Radial pulse only when liking
                    if !wasBumped {
                        fistBumpPulse = false
                        withAnimation(.easeOut(duration: 0.55)) {
                            fistBumpPulse = true
                        }
                    }
                }) {
                    ZStack {
                        // Pulse ring
                        Circle()
                            .stroke(accent.opacity(fistBumpPulse ? 0 : 0.55), lineWidth: fistBumpPulse ? 1 : 8)
                            .frame(width: 36, height: 36)
                            .scaleEffect(fistBumpPulse ? 1.9 : 0.6)
                            .opacity(fistBumpPulse ? 0 : 0.0)

                        Image(systemName: tour.isFistBumped ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 20))
                            .foregroundColor(tour.isFistBumped ? accent : .secondary)
                            .scaleEffect(fistBumpScale)
                            .symbolEffect(.bounce, value: fistBumpTrigger)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // Comment — subtle tilt/scale
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        commentScale = 0.82
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                            commentScale = 1.0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        showComments = true
                    }
                }) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .scaleEffect(commentScale)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // Bookmark — overshoot bounce
                Button(action: {
                    HapticManager.shared.light()
                    appState.toggleBookmark(tour: tour)
                    bookmarkTrigger += 1
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.38)) {
                        bookmarkScale = 1.4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            bookmarkScale = 1.0
                        }
                    }
                }) {
                    Image(systemName: tour.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20))
                        .foregroundColor(tour.isBookmarked ? accent : .secondary)
                        .scaleEffect(bookmarkScale)
                        .symbolEffect(.bounce, value: bookmarkTrigger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // Share
                ShareLink(item: "\(tour.playerName) conquered \(tour.summitName) — +\(tour.elevationGainMeters)m! Tracked with Ascent.") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .scaleEffect(shareScale)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .simultaneousGesture(TapGesture().onEnded {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                        shareScale = 0.85
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                            shareScale = 1.0
                        }
                    }
                })
            }
        }
    }
}

// MARK: - Stat Cell
private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Route Map Preview
struct RouteMapPreview: View {
    let coordinates: [CLLocationCoordinate2D]

    @AppStorage("routeColor") private var routeColorName: String = "blue"

    private var routeColor: Color {
        switch routeColorName {
        case "red":    return .red
        case "green":  return .green
        case "orange": return .orange
        default:       return DesignSystem.Colors.accent
        }
    }

    private var simplifiedCoordinates: [CLLocationCoordinate2D] {
        guard coordinates.count > 30 else { return coordinates }
        let step = coordinates.count / 30
        var result: [CLLocationCoordinate2D] = []
        for i in stride(from: 0, to: coordinates.count, by: step) {
            result.append(coordinates[i])
        }
        if let last = coordinates.last {
            result.append(last)
        }
        return result
    }

    var body: some View {
        Map {
            MapPolyline(coordinates: simplifiedCoordinates)
                .stroke(routeColor, lineWidth: 3)
            if let first = coordinates.first {
                Annotation("", coordinate: first) {
                    Circle().fill(.green).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if let last = coordinates.last, coordinates.count > 1 {
                Annotation("", coordinate: last) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .disabled(true)
        .allowsHitTesting(false)
    }
}

// =========================================
// === COMMENT SHEET ===
// =========================================

struct CommentSheetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let tour: Tour

    @State private var comments: [CommentDisplay] = []
    @State private var newCommentText = ""
    @State private var isLoading = true

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tour info header
                HStack(spacing: 10) {
                    Image(systemName: "mountain.2.fill")
                        .foregroundColor(accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tour.summitName)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                        Text("by \(tour.playerName)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))

                // Comments list
                if isLoading {
                    Spacer()
                    ProgressView().tint(.gray)
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                        Text("No comments yet")
                            .font(.system(.headline, design: .rounded)).foregroundColor(.gray)
                        Text("Be the first to leave a comment!")
                            .font(.system(.caption, design: .rounded)).foregroundColor(.gray.opacity(0.7))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                }

                // Input
                HStack(spacing: 10) {
                    TextField("Write a comment...", text: $newCommentText)
                        .font(.system(.subheadline, design: .rounded))
                        .padding(10)
                        .padding(.horizontal, 4)
                        .background(Color(white: 0.94))
                        .clipShape(Capsule())

                    Button(action: {
                        let text = newCommentText
                        newCommentText = ""
                        appState.postComment(tour: tour, body: text)
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            comments = await appState.fetchComments(tour: tour)
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(newCommentText.isEmpty ? .gray : accent)
                    }
                    .disabled(newCommentText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay(alignment: .top) { Divider() }
            }
            .background(Color(white: 0.99))
            .navigationTitle("Comments (\(comments.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
        }
        .task {
            comments = await appState.fetchComments(tour: tour)
            isLoading = false
        }
    }
}

// === COMMENT ROW ===
struct CommentRow: View {
    let comment: CommentDisplay

    private static let fmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let urlString = comment.avatarURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.2))
                    }
                } else {
                    Circle().fill(Color.gray.opacity(0.15))
                        .overlay(Text(String(comment.userName.prefix(1))).font(.system(.caption2, weight: .bold)).foregroundColor(.gray))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.userName)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                    Text(Self.fmt.localizedString(for: comment.date, relativeTo: Date()))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Text(comment.body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primary.opacity(0.85))
            }
            Spacer()
        }
    }
}

// === STAT BLOCK (backward compat) ===
struct StatBlock: View {
    let icon: String; let value: String; let isXP: Bool
    var body: some View {
        HStack(spacing: 6) {
            if !icon.isEmpty { Image(systemName: icon).font(.system(size: 10)).foregroundColor(isXP ? .blue : .gray) }
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(isXP ? DesignSystem.Colors.accent : .primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(isXP ? Color.blue.opacity(0.15) : Color(white: 0.95))
        .cornerRadius(8)
    }
}
