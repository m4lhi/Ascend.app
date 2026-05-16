import SwiftUI

// =========================================
// === DATEI: ArenaView.swift ===
// === Top Alpinists — pastel leaderboard ===
// =========================================
//
// In-place refactor of the old "Arena" leaderboard. Same call
// site (TabBar) and the same LeaderboardViewModel data sources;
// the visual layer is now pastel, sentence-case, custom-glyph
// based. Per Iteration 14:
//
//   - "Top Alpinists" title, "Worldwide / In your region / Your
//     friends" subtitle.
//   - World / Region / Friends scope selector with custom glyphs.
//   - Time filter (Week / Month / All time), client-side fallback.
//   - Pastel podium for the top 3, AlpinistRow for ranks 4+.
//   - MotivationalBanner with gap-progress (not absolute %).
//   - Friends + Region empty states.
//   - Add-Friend sheet with the user's own handle on top for
//     easy sharing.
//
// Phase 2 (separate iteration) adds the Mountain tab, real
// backend time queries, and the regional system.

struct ArenaView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var leaderboardVM: LeaderboardViewModel

    @State private var selectedScope: LeaderboardScope = .global
    @State private var selectedTime: LeaderboardTime = .allTime
    @State private var showingAddFriendSheet = false
    @State private var selectedProfile: CloudProfile?

    // MARK: - Body

    var body: some View {
        ZStack {
            DesignSystem.Colors.paperWarm
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScopeSelector(selectedScope: $selectedScope)
                    .padding(.top, DesignSystem.Spacing.md)
                TimeFilter(selectedTime: $selectedTime)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        content
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
        }
        .onAppear {
            leaderboardVM.fetchLeaderboard()
        }
        .sheet(isPresented: $showingAddFriendSheet) {
            AddFriendSheet()
                .environmentObject(appState)
                .environmentObject(profileVM)
                .environmentObject(leaderboardVM)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(36)
        }
        .sheet(item: $selectedProfile) { p in
            PublicProfileView(
                userId: p.id,
                userName: p.username,
                userHandle: p.handle,
                avatarURL: p.avatar_url,
                xp: p.xp
            )
            .presentationDetents([.fraction(0.85), .large])
            .environmentObject(appState)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Top Alpinists")
                    .font(DesignSystem.Typography.title2Inter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)

                Text(subtitleForCurrentScope)
                    .font(DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
            }

            Spacer()

            Button { showingAddFriendSheet = true } label: {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.glacierSoft)
                        .frame(width: 38, height: 38)
                    ZStack {
                        Rectangle()
                            .fill(DesignSystem.Colors.glacierDeep)
                            .frame(width: 12, height: 1.5)
                        Rectangle()
                            .fill(DesignSystem.Colors.glacierDeep)
                            .frame(width: 1.5, height: 12)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private var subtitleForCurrentScope: String {
        switch selectedScope {
        case .global:   return "Worldwide"
        case .regional: return "In your region"
        case .friends:  return "Your friends"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedScope {
        case .regional:
            RegionEmptyState()
                .padding(.horizontal, DesignSystem.Spacing.lg)
        case .friends:
            if filteredEntries.count <= 1 {
                FriendsEmptyState(onAddFriend: { showingAddFriendSheet = true })
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            } else {
                podiumAndRows
            }
        case .global:
            if filteredEntries.isEmpty {
                emptyTimeRange
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            } else {
                podiumAndRows
            }
        }
    }

    @ViewBuilder
    private var podiumAndRows: some View {
        let entries = filteredEntries
        let topThree = Array(entries.prefix(3))
        let rest = Array(entries.dropFirst(3))

        if !topThree.isEmpty {
            AlpinistPodium(
                topThree: topThree,
                currentUserHandle: profileVM.userHandle,
                onTap: { selectedProfile = $0 }
            )
        }

        if !rest.isEmpty {
            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(rest.enumerated()), id: \.element.id) { idx, profile in
                    AlpinistRow(
                        profile: profile,
                        rank: idx + 4,
                        currentUserHandle: profileVM.userHandle,
                        onTap: { selectedProfile = profile }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }

        if let myProfile = currentUserProfile(in: entries),
           let myIndex = entries.firstIndex(where: { $0.id == myProfile.id }),
           myIndex >= 3 {
            MotivationalBanner(
                userRank: myIndex + 1,
                userXP: myProfile.xp,
                nextProfile: myIndex > 0 ? entries[myIndex - 1] : nil
            )
        }
    }

    private var emptyTimeRange: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("No data for this time range yet")
                .font(DesignSystem.Typography.title3Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
            Text("Switch to All time to see the full leaderboard.")
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }

    // MARK: - Data

    /// Source list for the current scope, time-filtered when possible.
    /// CloudProfile has no lastActivityDate today, so Week/Month
    /// degrade to the full list — see filter helper.
    private var filteredEntries: [CloudProfile] {
        let source: [CloudProfile]
        switch selectedScope {
        case .global:   source = leaderboardVM.globalLeaderboard
        case .regional: source = []
        case .friends:  source = leaderboardVM.friendsLeaderboard
        }
        return timeFiltered(source)
    }

    /// Phase-1 client-side time filter. CloudProfile doesn't expose
    /// a timestamp yet, so Week / Month currently return the same
    /// list as All time. Once the model + backend land, swap this
    /// for the real check on `profile.lastActivityDate`.
    private func timeFiltered(_ source: [CloudProfile]) -> [CloudProfile] {
        switch selectedTime {
        case .allTime, .week, .month:
            return source
        }
    }

    private func currentUserProfile(in entries: [CloudProfile]) -> CloudProfile? {
        entries.first { $0.handle == profileVM.userHandle }
    }
}

// =========================================
// MARK: - Scope selector
// =========================================

enum LeaderboardScope: String, CaseIterable {
    case global, regional, friends

    var title: String {
        switch self {
        case .global:   return "World"
        case .regional: return "Region"
        case .friends:  return "Friends"
        }
    }
}

struct ScopeSelector: View {
    @Binding var selectedScope: LeaderboardScope
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                Button {
                    withAnimation(DesignSystem.Animations.standard) {
                        selectedScope = scope
                    }
                } label: {
                    HStack(spacing: 6) {
                        scopeGlyph(scope)
                            .frame(width: 16, height: 16)
                        Text(scope.title)
                            .font(DesignSystem.Typography.subheadInter)
                    }
                    .foregroundStyle(
                        selectedScope == scope
                            ? DesignSystem.Colors.inkWarm
                            : DesignSystem.Colors.inkWarm.opacity(0.55)
                    )
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background {
                        if selectedScope == scope {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                .fill(DesignSystem.Colors.paperWarm)
                                .matchedGeometryEffect(id: "selectedPill", in: pillNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(DesignSystem.Colors.surfaceWarm)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    @ViewBuilder
    private func scopeGlyph(_ scope: LeaderboardScope) -> some View {
        let stroke = DesignSystem.Colors.inkWarm.opacity(selectedScope == scope ? 0.85 : 0.55)
        switch scope {
        case .global:
            ZStack {
                Circle()
                    .stroke(stroke, lineWidth: 1.4)
                Path { p in
                    p.move(to: CGPoint(x: 3, y: 8))
                    p.addQuadCurve(to: CGPoint(x: 13, y: 8), control: CGPoint(x: 8, y: 4))
                }
                .stroke(stroke, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        case .regional:
            Path { p in
                p.move(to: CGPoint(x: 8, y: 14))
                p.addLine(to: CGPoint(x: 4, y: 7))
                p.addArc(center: CGPoint(x: 8, y: 7), radius: 4,
                         startAngle: .degrees(180), endAngle: .degrees(0),
                         clockwise: false)
                p.addLine(to: CGPoint(x: 8, y: 14))
            }
            .stroke(stroke, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        case .friends:
            ZStack {
                Circle()
                    .stroke(stroke, lineWidth: 1.4)
                    .frame(width: 9, height: 9)
                    .offset(x: -2.5)
                Circle()
                    .stroke(stroke, lineWidth: 1.4)
                    .frame(width: 9, height: 9)
                    .offset(x: 2.5)
            }
        }
    }
}

// =========================================
// MARK: - Time filter
// =========================================

enum LeaderboardTime: String, CaseIterable {
    case week, month, allTime

    var title: String {
        switch self {
        case .week:    return "This week"
        case .month:   return "This month"
        case .allTime: return "All time"
        }
    }
}

struct TimeFilter: View {
    @Binding var selectedTime: LeaderboardTime

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(LeaderboardTime.allCases, id: \.self) { time in
                Button {
                    withAnimation(DesignSystem.Animations.quick) {
                        selectedTime = time
                    }
                } label: {
                    Text(time.title)
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(
                            selectedTime == time
                                ? DesignSystem.Colors.inkWarm
                                : DesignSystem.Colors.inkFaintWarm
                        )
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(selectedTime == time
                                      ? DesignSystem.Colors.paperWarm
                                      : Color.clear)
                                .overlay(
                                    Capsule().stroke(
                                        selectedTime == time
                                            ? DesignSystem.Colors.borderSubtle
                                            : Color.clear,
                                        lineWidth: 0.5
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.sm)
    }
}

// =========================================
// MARK: - Avatar rotation helper
// =========================================

/// Pick one of the three mood assets deterministically from a handle
/// so each user has a consistent fallback avatar (and the list reads
/// varied instead of three rows of the same character). Sum of UTF-8
/// bytes is stable across app launches — Swift's String.hashValue is
/// randomized per process and would not be.
fileprivate func fallbackAvatarName(for handle: String) -> String {
    let assets = ["hero-ready", "hero-rest", "hero-caution"]
    let normalized = handle.lowercased()
    let sum = normalized.utf8.reduce(0) { $0 + Int($1) }
    return assets[sum % assets.count]
}

// =========================================
// MARK: - Podium (Top 3)
// =========================================

struct AlpinistPodium: View {
    let topThree: [CloudProfile]
    let currentUserHandle: String?
    let onTap: (CloudProfile) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            if topThree.count > 1 {
                podiumCard(profile: topThree[1], rank: 2, height: 150)
            }
            if let first = topThree.first {
                podiumCard(profile: first, rank: 1, height: 180)
            }
            if topThree.count > 2 {
                podiumCard(profile: topThree[2], rank: 3, height: 135)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func podiumCard(profile: CloudProfile, rank: Int, height: CGFloat) -> some View {
        Button { onTap(profile) } label: {
            VStack(spacing: DesignSystem.Spacing.xs) {
                avatar(for: profile)
                    .frame(width: rank == 1 ? 64 : 52, height: rank == 1 ? 64 : 52)
                    .clipShape(Circle())

                Text(profile.username)
                    .font(rank == 1
                          ? DesignSystem.Typography.bodyEmphasisInter
                          : DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                    .lineLimit(1)

                Text("\(profile.xp) XP")
                    .font(DesignSystem.Typography.kickerInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                    .monospacedDigit()

                Text("#\(rank)")
                    .font(DesignSystem.Typography.kickerInter)
                    .foregroundStyle(rankColor(rank))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(DesignSystem.Colors.paperWarm))
                    .overlay(
                        Capsule().stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
                    )
            }
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                    .fill(cardBackground(rank))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatar(for profile: CloudProfile) -> some View {
        if let url = profile.avatar_url, let parsed = URL(string: url), !url.isEmpty {
            AsyncImage(url: parsed) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    fallbackAvatar(for: profile.handle)
                }
            }
        } else {
            fallbackAvatar(for: profile.handle)
        }
    }

    private func fallbackAvatar(for handle: String) -> some View {
        Image(fallbackAvatarName(for: handle))
            .resizable()
            .scaledToFit()
            .background(DesignSystem.Colors.paperWarm)
    }

    private func cardBackground(_ rank: Int) -> Color {
        switch rank {
        case 1: return DesignSystem.Colors.alpenglowSoft
        case 2: return DesignSystem.Colors.glacierSoft
        case 3: return DesignSystem.Colors.sageCard
        default: return DesignSystem.Colors.paperWarm
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return DesignSystem.Colors.alpenglow
        case 2: return DesignSystem.Colors.glacierDeep
        case 3: return DesignSystem.Colors.meadow
        default: return DesignSystem.Colors.inkWarm.opacity(0.62)
        }
    }
}

// =========================================
// MARK: - List row (ranks 4+)
// =========================================

struct AlpinistRow: View {
    let profile: CloudProfile
    let rank: Int
    let currentUserHandle: String?
    let onTap: () -> Void

    private var isCurrentUser: Bool {
        profile.handle == currentUserHandle
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Text("\(rank)")
                    .font(DesignSystem.Typography.bodyEmphasisInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                    .frame(width: 28, alignment: .leading)
                    .monospacedDigit()

                avatarView
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.username)
                            .font(DesignSystem.Typography.bodyEmphasisInter)
                            .foregroundStyle(DesignSystem.Colors.inkWarm)
                            .lineLimit(1)

                        if isCurrentUser {
                            Text("you")
                                .font(DesignSystem.Typography.kickerInter)
                                .foregroundStyle(DesignSystem.Colors.alpenglow)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(
                                    Capsule().fill(DesignSystem.Colors.alpenglowSoft)
                                )
                        }
                    }

                    Text("@\(profile.handle)")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(profile.xp)")
                        .font(DesignSystem.Typography.bodyEmphasisInter)
                        .foregroundStyle(DesignSystem.Colors.inkWarm)
                        .monospacedDigit()
                    Text("XP")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                    .fill(isCurrentUser
                          ? DesignSystem.Colors.alpenglowSoft
                          : DesignSystem.Colors.surfaceWarm)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarView: some View {
        let fallbackName = fallbackAvatarName(for: profile.handle)
        if let url = profile.avatar_url, let parsed = URL(string: url), !url.isEmpty {
            AsyncImage(url: parsed) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Image(fallbackName).resizable().scaledToFit()
                }
            }
        } else {
            Image(fallbackName).resizable().scaledToFit()
        }
    }
}

// =========================================
// MARK: - Motivational banner
// =========================================

struct MotivationalBanner: View {
    let userRank: Int
    let userXP: Int
    let nextProfile: CloudProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("#\(userRank)")
                    .font(DesignSystem.Typography.title3Inter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                    .monospacedDigit()

                Text(positionLabel)
                    .font(DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
            }

            if let next = nextProfile {
                let gap = max(0, next.xp - userXP)

                Text(motivationalText(gap: gap, nextName: next.username))
                    .font(DesignSystem.Typography.bodyInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                gapProgressBar(gap: gap)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(DesignSystem.Colors.alpenglowSoft)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var positionLabel: String {
        switch userRank {
        case 1...3:   return "on the podium"
        case 4...10:  return "in the Top 10"
        case 11...50: return "in the Top 50"
        default:      return "in the leaderboard"
        }
    }

    private func motivationalText(gap: Int, nextName: String) -> String {
        if gap < 100 {
            return "Only \(gap) XP to \(nextName) — almost there."
        } else if gap < 500 {
            return "\(gap) XP to \(nextName). One tour could do it."
        } else {
            return "\(gap) XP to \(nextName)."
        }
    }

    /// Closer to the next alpinist = fuller bar. 0 gap = full,
    /// 1000+ gap = empty. Visual signal, not absolute progress.
    @ViewBuilder
    private func gapProgressBar(gap: Int) -> some View {
        let progressFraction = CGFloat(max(0, min(1, 1.0 - Double(gap) / 1000.0)))

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignSystem.Colors.alpenglowSoft.opacity(0.5))
                Capsule()
                    .fill(DesignSystem.Colors.alpenglow)
                    .frame(width: geo.size.width * progressFraction)
            }
        }
        .frame(height: 4)
    }
}

// =========================================
// MARK: - Empty states
// =========================================

struct FriendsEmptyState: View {
    let onAddFriend: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image("hero-ready")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 120)
                .opacity(0.6)

            Text("No friends yet")
                .font(DesignSystem.Typography.title3Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)

            Text("Mountains are better with company. Invite someone by their handle.")
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            Button(action: onAddFriend) {
                Text("Add friend")
                    .font(DesignSystem.Typography.bodyEmphasisInter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .background(Capsule().fill(DesignSystem.Colors.alpenglow))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

struct RegionEmptyState: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Region not set yet")
                .font(DesignSystem.Typography.title3Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)

            Text("Coming soon — you'll be able to see who's on top in your region.")
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// =========================================
// MARK: - Add friend sheet
// =========================================

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var leaderboardVM: LeaderboardViewModel

    @State private var handleInput: String = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.paperWarm.ignoresSafeArea()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Your handle to share")
                            .font(DesignSystem.Typography.kickerInter)
                            .foregroundStyle(DesignSystem.Colors.inkFaintWarm)

                        Text("@\(profileVM.userHandle.isEmpty ? "—" : profileVM.userHandle)")
                            .font(DesignSystem.Typography.title3Inter)
                            .foregroundStyle(DesignSystem.Colors.inkWarm)
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                    .fill(DesignSystem.Colors.surfaceWarm)
                            )
                    }

                    Divider()
                        .background(DesignSystem.Colors.borderSubtle)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Friend's handle")
                            .font(DesignSystem.Typography.kickerInter)
                            .foregroundStyle(DesignSystem.Colors.inkFaintWarm)

                        HStack {
                            Text("@")
                                .font(DesignSystem.Typography.bodyEmphasisInter)
                                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))

                            TextField("name", text: $handleInput)
                                .font(DesignSystem.Typography.bodyInter)
                                .foregroundStyle(DesignSystem.Colors.inkWarm)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                .fill(DesignSystem.Colors.paperWarm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                        .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
                                )
                        )
                    }

                    Spacer()

                    Button(action: submit) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(DesignSystem.Colors.inkOnSand)
                            }
                            Text(isSubmitting ? "Adding…" : "Add")
                                .font(DesignSystem.Typography.bodyEmphasisInter)
                                .foregroundStyle(DesignSystem.Colors.inkOnSand)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            Capsule().fill(
                                handleInput.isEmpty
                                    ? DesignSystem.Colors.inkFaintWarm.opacity(0.6)
                                    : DesignSystem.Colors.alpenglow
                            )
                        )
                    }
                    .disabled(handleInput.isEmpty || isSubmitting)
                    .buttonStyle(.plain)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("Add friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                }
            }
        }
    }

    private func submit() {
        let trimmed = handleInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        leaderboardVM.addFriend(handleToSearch: trimmed)
        // addFriend is fire-and-forget Task — dismiss optimistically.
        // The friends list refreshes on completion via leaderboardVM
        // observer in the parent.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dismiss()
        }
    }
}
