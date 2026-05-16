import SwiftUI

// =========================================
// === DATEI: ActivityCardView.swift ===
// === TourCard — editorial pastel tour card ===
// =========================================
//
// Replaces the Komoot-style social-feed card from the old
// ArenaView era. Same data (Tour) + same social interactions
// (fist bump, comment, bookmark, open detail) — new visual
// vocabulary:
//
//   - Editorial header: avatar + name/handle + relative time.
//   - Mountain name as a title2Inter editorial statement.
//   - Optional photo with soft rounded corners (no map-photo
//     carousel — map lives in the detail view).
//   - Inline stat row: duration · elevation · distance.
//   - Minimal glyph-based action row (FistBumpGlyph, CommentGlyph,
//     BookmarkGlyph) with alpenglow accent on the active state.
//
// File name kept as ActivityCardView.swift; the struct is
// TourCard so it can be referenced by the iteration 16 ToursView.

struct TourCard: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var feedVM: FeedViewModel
    let tour: Tour

    @State private var showDetail = false
    @State private var fistBumpScale: CGFloat = 1.0
    @State private var bookmarkScale: CGFloat = 1.0

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

    private var formattedDuration: String {
        Self.durationFormatter.string(from: tour.durationSeconds) ?? "0m"
    }

    private var timeAgo: String {
        Self.relativeFormatter.string(for: tour.date) ?? "just now"
    }

    private var validPhotoURL: URL? {
        guard let urlString = tour.photoURL,
              !urlString.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return URL(string: urlString)
    }

    /// Deterministic avatar variant from the handle so each user has
    /// a consistent fallback. UTF-8 byte sum keeps it stable across
    /// app launches (Swift's String.hashValue is randomized per process).
    private func fallbackAvatarName(for handle: String) -> String {
        let assets = ["hero-ready", "hero-rest", "hero-caution"]
        let normalized = handle.lowercased()
        let sum = normalized.utf8.reduce(0) { $0 + Int($1) }
        return assets[sum % assets.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {

            userHeader

            Text(tour.summitName)
                .font(DesignSystem.Typography.title2Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .fixedSize(horizontal: false, vertical: true)

            if let photoURL = validPhotoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(DesignSystem.Colors.surfaceWarm)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { showDetail = true }
            }

            if !tour.storyComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(tour.storyComment)
                    .font(DesignSystem.Typography.bodyInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
                    .lineLimit(3)
            }

            statsRow

            Divider().background(DesignSystem.Colors.borderSubtle)

            actionRow
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(DesignSystem.Colors.paperWarm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .fullScreenCover(isPresented: $showDetail) {
            TourDetailView(tour: tour)
        }
    }

    // MARK: - Sub-sections

    private var userHeader: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            avatar
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tour.playerName)
                        .font(DesignSystem.Typography.bodyEmphasisInter)
                        .foregroundStyle(DesignSystem.Colors.inkWarm)
                        .lineLimit(1)

                    if tour.isCurrentUser {
                        Text("you")
                            .font(DesignSystem.Typography.kickerInter)
                            .foregroundStyle(DesignSystem.Colors.alpenglow)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(DesignSystem.Colors.alpenglowSoft))
                    }
                }

                Text(timeAgo)
                    .font(DesignSystem.Typography.kickerInter)
                    .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var avatar: some View {
        let fallback = fallbackAvatarName(for: tour.playerHandle)
        if let urlString = tour.playerAvatarURL,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Image(fallback).resizable().scaledToFit()
                }
            }
        } else {
            Image(fallback).resizable().scaledToFit()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 6) {
            Text(formattedDuration)
            Text("·").foregroundStyle(DesignSystem.Colors.inkFaintWarm)
            Text("\(tour.elevationGainMeters) m")
            Text("·").foregroundStyle(DesignSystem.Colors.inkFaintWarm)
            Text(String(format: "%.1f km", tour.distanceKilometers))
        }
        .font(DesignSystem.Typography.subheadInter)
        .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
        .monospacedDigit()
    }

    private var actionRow: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            actionButton(
                glyph: AnyView(FistBumpGlyph(filled: tour.isFistBumped)),
                count: tour.fistBumpCount,
                isActive: tour.isFistBumped,
                scale: fistBumpScale,
                action: handleFistBump
            )

            actionButton(
                glyph: AnyView(CommentGlyph()),
                count: tour.commentCount,
                isActive: false,
                scale: 1.0,
                action: handleCommentTap
            )

            Spacer()

            actionButton(
                glyph: AnyView(BookmarkGlyph(filled: tour.isBookmarked)),
                count: nil,
                isActive: tour.isBookmarked,
                scale: bookmarkScale,
                action: handleBookmark
            )
        }
    }

    private func actionButton(
        glyph: AnyView,
        count: Int?,
        isActive: Bool,
        scale: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                glyph
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isActive
                                     ? DesignSystem.Colors.alpenglow
                                     : DesignSystem.Colors.inkWarm.opacity(0.62))
                    .scaleEffect(scale)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(DesignSystem.Typography.subheadInter)
                        .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleFistBump() {
        HapticManager.shared.light()
        withAnimation(.snappy(duration: 0.15)) { fistBumpScale = 1.35 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.1)) {
            fistBumpScale = 1.0
        }
        feedVM.toggleFistBump(tour: tour)
    }

    private func handleBookmark() {
        HapticManager.shared.light()
        withAnimation(.snappy(duration: 0.15)) { bookmarkScale = 1.35 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.1)) {
            bookmarkScale = 1.0
        }
        feedVM.toggleBookmark(tour: tour)
    }

    private func handleCommentTap() {
        // TODO: wire to a comments sheet once one exists. For now,
        // tapping the comment glyph opens the detail screen.
        showDetail = true
    }
}
