import SwiftUI
import MapKit

// =========================================
// === DATEI: ActivityCardView.swift ===
// === Social Feed Card mit Route Map ===
// =========================================

struct ActivityCardView: View {
    @EnvironmentObject var appState: AppState

    let tour: Tour

    @State private var showComments = false

    // Static formatters — allocated once, reused across all cards
    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var formattedDuration: String {
        Self.durationFormatter.string(from: tour.durationSeconds) ?? "0m"
    }

    var timeAgo: String {
        Self.relativeFormatter.string(for: tour.date)?.uppercased() ?? "JUST NOW"
    }

    private let accentBlue = Color(red: 0.1, green: 0.5, blue: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // === HEADER ROW ===
            HStack(alignment: .center, spacing: 12) {
                // Avatar
                if let urlString = tour.playerAvatarURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color.pink.opacity(0.3), Color.blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                        .overlay(Text(String(tour.playerName.prefix(1))).fontWeight(.bold).foregroundColor(.white))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tour.playerName)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        if !tour.isCurrentUser {
                            Text("@\(tour.playerHandle)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    Text(timeAgo)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                }
                Spacer()

                if tour.isCurrentUser {
                    Menu {
                        Button(role: .destructive, action: {
                            appState.deleteTour(tour: tour)
                        }) {
                            Label("Delete Mission", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16)).foregroundColor(.gray)
                            .padding(8).contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // === ROUTE MAP (if route data exists) ===
            if !tour.routeCoordinates.isEmpty {
                RouteMapPreview(coordinates: tour.routeCoordinates)
                    .frame(height: 160)
                    .clipShape(Rectangle())
            }

            // === TOUR PHOTO ===
            if let photoURL = tour.photoURL, let url = URL(string: photoURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: tour.routeCoordinates.isEmpty ? 200 : 140)
                        .clipped()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.1))
                        .frame(height: tour.routeCoordinates.isEmpty ? 200 : 140)
                        .overlay(ProgressView().tint(.gray))
                }
            }

            // === CONTENT ===
            VStack(alignment: .leading, spacing: 10) {

                // Summit tag
                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accentBlue)
                    Text(tour.summitName.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(accentBlue)
                        .tracking(1)
                }

                // Story text
                if !tour.storyComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(tour.storyComment)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary.opacity(0.9))
                        .lineSpacing(3)
                        .lineLimit(3)
                }

                // === STATS BAR ===
                HStack(spacing: 0) {
                    MiniStat(icon: "arrow.up.right", value: "+\(tour.elevationGainMeters)m")
                    MiniStat(icon: "clock.fill", value: formattedDuration)
                    if tour.distanceKilometers > 0 {
                        MiniStat(icon: "figure.walk", value: String(format: "%.1fkm", tour.distanceKilometers))
                    }
                    Spacer()
                    Text("+\(tour.xpGained) XP")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(accentBlue)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(accentBlue.opacity(0.12))
                        .clipShape(Capsule())
                }

                // === SOCIAL ACTION BAR ===
                Divider().opacity(0.3)

                HStack(spacing: 0) {
                    // Fist Bump
                    Button(action: {
                        HapticManager.shared.light()
                        appState.toggleFistBump(tour: tour)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tour.isFistBumped ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 14))
                                .foregroundColor(tour.isFistBumped ? accentBlue : .gray)
                            if tour.fistBumpCount > 0 {
                                Text("\(tour.fistBumpCount)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(tour.isFistBumped ? accentBlue : .gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Comments
                    Button(action: { showComments = true }) {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 14))
                                .foregroundColor(tour.commentCount > 0 ? .primary : .gray)
                            if tour.commentCount > 0 {
                                Text("\(tour.commentCount)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Bookmark
                    Button(action: {
                        HapticManager.shared.light()
                        appState.toggleBookmark(tour: tour)
                    }) {
                        Image(systemName: tour.isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14))
                            .foregroundColor(tour.isBookmarked ? accentBlue : .gray)
                            .frame(maxWidth: .infinity)
                    }

                    // Share
                    ShareLink(item: "\(tour.playerName) conquered \(tour.summitName) — +\(tour.elevationGainMeters)m elevation! Tracked with Ascent.") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .light)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 15, y: 6)
        .sheet(isPresented: $showComments) {
            CommentSheetView(tour: tour)
                .presentationDetents([.medium, .large])
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Mini Route Map Preview
struct RouteMapPreview: View {
    let coordinates: [CLLocationCoordinate2D]

    @AppStorage("routeColor") private var routeColorName: String = "blue"

    private var routeColor: Color {
        switch routeColorName {
        case "red":    return .red
        case "green":  return .green
        case "orange": return .orange
        default:       return Color(red: 0.1, green: 0.5, blue: 0.95)
        }
    }

    var body: some View {
        Map {
            MapPolyline(coordinates: coordinates)
                .stroke(routeColor, lineWidth: 3)

            // Start marker
            if let first = coordinates.first {
                Annotation("", coordinate: first) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }

            // End marker
            if let last = coordinates.last, coordinates.count > 1 {
                Annotation("", coordinate: last) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .disabled(true) // Non-interactive preview
        .allowsHitTesting(false)
    }
}

// MARK: - Mini Stat
private struct MiniStat: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
        }
        .padding(.trailing, 12)
    }
}

// === COMMENT SHEET ===
struct CommentSheetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let tour: Tour

    @State private var comments: [CommentDisplay] = []
    @State private var newCommentText = ""
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.98).ignoresSafeArea()

                VStack(spacing: 0) {
                    if isLoading {
                        Spacer()
                        ProgressView().tint(.gray)
                        Spacer()
                    } else if comments.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 36, design: .rounded)).foregroundColor(.gray.opacity(0.5))
                            Text("No comments yet").font(.system(.headline, design: .rounded)).foregroundColor(.gray)
                            Text("Be the first to comment!").font(.system(.caption, design: .rounded)).foregroundColor(.gray.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(comments) { comment in
                                    CommentRow(comment: comment)
                                }
                            }
                            .padding(20)
                        }
                    }

                    // Input field
                    HStack(spacing: 12) {
                        TextField("Write a comment...", text: $newCommentText)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(white: 0.93))
                            .cornerRadius(20)

                        Button(action: {
                            appState.postComment(tour: tour, body: newCommentText)
                            newCommentText = ""
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                comments = await appState.fetchComments(tour: tour)
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32, design: .rounded))
                                .foregroundColor(newCommentText.isEmpty ? .gray : Color(red: 0.1, green: 0.5, blue: 0.95))
                        }
                        .disabled(newCommentText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray).font(.system(.title3, design: .rounded))
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

    private static let commentTimeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var timeAgo: String {
        Self.commentTimeFormatter.localizedString(for: comment.date, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let urlString = comment.avatarURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 32, height: 32).clipShape(Circle())
            } else {
                Circle().fill(Color.gray.opacity(0.2)).frame(width: 32, height: 32)
                    .overlay(Text(String(comment.userName.prefix(1))).font(.system(.caption2, design: .rounded)).fontWeight(.bold).foregroundColor(.gray))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.userName).font(.system(.caption, design: .rounded)).fontWeight(.bold).foregroundColor(.primary)
                    Text(timeAgo).font(.system(.caption2, design: .rounded)).foregroundColor(.gray)
                }
                Text(comment.body).font(.system(.subheadline, design: .rounded)).foregroundColor(.primary.opacity(0.9))
            }
            Spacer()
        }
    }
}

// === STAT BLOCK (kept for backward compat) ===
struct StatBlock: View {
    let icon: String
    let value: String
    let isXP: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon).font(.system(size: 10, design: .rounded)).foregroundColor(isXP ? .blue : .gray)
            }
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(isXP ? Color(red: 0.1, green: 0.5, blue: 0.95) : .primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(isXP ? Color.blue.opacity(0.15) : Color(white: 0.95))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isXP ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1))
    }
}
