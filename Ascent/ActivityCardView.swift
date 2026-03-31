import SwiftUI

// =========================================
// === DATEI: ActivityCardView.swift ===
// === Social Feed Card mit Cloud Actions ===
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

    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // === TOP ROW ===
            HStack(alignment: .top, spacing: 12) {
                if let urlString = tour.playerAvatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 45, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.3), Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 45, height: 45)
                        .overlay(Text(String(tour.playerName.prefix(1))).fontWeight(.bold).foregroundColor(.white))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(tour.playerName).font(.system(.headline, design: .rounded)).foregroundColor(.primary)
                        if !tour.isCurrentUser {
                            Text("@\(tour.playerHandle)").font(.system(.caption, design: .rounded)).foregroundColor(.gray)
                        }
                    }
                    Text(timeAgo).font(.system(.caption2, design: .rounded)).foregroundColor(.gray).fontWeight(.bold)
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
                            .font(.system(.title3, design: .rounded)).foregroundColor(.gray)
                            .padding(8).contentShape(Rectangle())
                    }
                }
            }

            // === STORY TEXT ===
            VStack(alignment: .leading, spacing: 6) {
                // Location Tag
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(gold)
                    Text(tour.summitName.uppercased())
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(gold)
                        .tracking(1) // Leichter Letter-Spacing für Premium-Look
                }
                
                // Content Text
                if !tour.storyComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(tour.storyComment)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary.opacity(0.9))
                        .lineSpacing(4)
                }
            }

            // === TOUR PHOTO ===
            if let photoURL = tour.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 200)
                            .clipped().cornerRadius(12)
                    } else if phase.error != nil {
                        EmptyView()
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
                            .frame(height: 200).overlay(ProgressView().tint(.white))
                    }
                }
            }

            // === STATS ===
            HStack(spacing: 10) {
                StatBlock(icon: "chart.bar.fill", value: "+\(tour.elevationGainMeters)m", isXP: false)
                StatBlock(icon: "clock.fill", value: formattedDuration, isXP: false)
                if tour.pauseCount > 0 {
                    StatBlock(icon: "pause.circle.fill", value: "\(tour.pauseCount) pauses", isXP: false)
                }
                StatBlock(icon: "", value: "+\(tour.xpGained) XP", isXP: true)
            }

            // === SOCIAL ACTION BAR ===
            HStack(spacing: 0) {
                // Fist Bump
                Button(action: {
                    HapticManager.shared.light()
                    appState.toggleFistBump(tour: tour)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tour.isFistBumped ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(tour.isFistBumped ? gold : .gray)
                        if tour.fistBumpCount > 0 {
                            Text("\(tour.fistBumpCount)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(tour.isFistBumped ? gold : .gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Comments
                Button(action: { showComments = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14, design: .rounded))
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
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(tour.isBookmarked ? gold : .gray)
                        .frame(maxWidth: .infinity)
                }

                // Share
                ShareLink(item: "\(tour.playerName) conquered \(tour.summitName) — +\(tour.elevationGainMeters)m elevation! Tracked with Ascent.") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 5)
        }
        .padding(20)
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

                    // Eingabefeld
                    HStack(spacing: 12) {
                        TextField("Write a comment...", text: $newCommentText)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(white: 0.93))
                            .cornerRadius(20)

                        Button(action: {
                            appState.postComment(tour: tour, body: newCommentText)
                            newCommentText = ""
                            // Reload nach kurzer Verzögerung
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

// === EINZELNER KOMMENTAR ===
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
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
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

// === STAT BLOCK ===
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
