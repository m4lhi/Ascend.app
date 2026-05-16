import SwiftUI

// =========================================
// === DATEI: AchievementsView.swift ===
// === Pure achievement gallery, pastel ===
// =========================================
//
// Separates the achievement gallery from the profile view. The
// Achievement / AchievementCategory / AchievementEngine types
// still live in TrophyRoomView.swift and are reused as-is — this
// view just consumes AchievementEngine.compute(...) and renders.
//
// User-flow (per iteration 20 audit answers):
//   - Always show the full list (no "empty" state vacuum).
//   - When 0 unlocked: encouragement card on top + locked list
//     under a "What you can earn" header — onboarding feels
//     actionable, not deserted.
//   - When ≥ 1 unlocked: unlocked group on top + locked group
//     dimmed under a "Locked" header.

struct AchievementsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var leaderboardVM: LeaderboardViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: AchievementCategory? = nil

    private var allAchievements: [Achievement] {
        AchievementEngine.compute(from: appState, feedVM: feedVM, leaderboardVM: leaderboardVM)
    }

    private var filtered: [Achievement] {
        guard let cat = selectedCategory else { return allAchievements }
        return allAchievements.filter { $0.category == cat }
    }

    private var unlocked: [Achievement] {
        filtered.filter { $0.isUnlocked }
    }

    private var locked: [Achievement] {
        filtered.filter { !$0.isUnlocked }
    }

    private var totalUnlockedCount: Int {
        allAchievements.filter { $0.isUnlocked }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.paperWarm.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {

                        progressHeader

                        categoryFilter

                        if totalUnlockedCount == 0 {
                            encouragementCard
                            roadmapSection
                        } else {
                            if !unlocked.isEmpty {
                                sectionHeader("Unlocked", count: unlocked.count)
                                achievementsList(unlocked, dimmed: false)
                            }
                            if !locked.isEmpty {
                                sectionHeader("Locked", count: locked.count)
                                achievementsList(locked, dimmed: true)
                            }
                        }

                        Spacer().frame(height: DesignSystem.Spacing.xxl)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.surfaceWarm)
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        let total = allAchievements.count
        let ratio = total > 0 ? Double(totalUnlockedCount) / Double(total) : 0

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(totalUnlockedCount)")
                    .font(.custom("Inter", size: 36).weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                    .monospacedDigit()
                Text("of \(total) earned")
                    .font(DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.Colors.surfaceWarm)
                        .frame(height: 6)
                    Capsule()
                        .fill(DesignSystem.Colors.alpenglow)
                        .frame(width: geo.size.width * ratio, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(DesignSystem.Colors.alpenglowSoft.opacity(0.5))
        )
    }

    // MARK: - Category filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(category: nil, label: "All")
                ForEach(AchievementCategory.allCases, id: \.self) { cat in
                    filterPill(category: cat, label: cat.rawValue)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterPill(category: AchievementCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(DesignSystem.Animations.quick) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 5) {
                if let cat = category {
                    categoryGlyph(cat)
                        .frame(width: 14, height: 14)
                }
                Text(label)
                    .font(DesignSystem.Typography.kickerInter)
            }
            .foregroundStyle(isSelected
                             ? DesignSystem.Colors.inkOnSand
                             : DesignSystem.Colors.inkWarm.opacity(0.62))
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    isSelected
                        ? DesignSystem.Colors.alpenglow
                        : DesignSystem.Colors.surfaceWarm
                )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func categoryGlyph(_ cat: AchievementCategory) -> some View {
        switch cat {
        case .milestone: MilestoneGlyph()
        case .weekly:    WeeklyGlyph()
        case .social:    SocialGlyph()
        case .explorer:  ExplorerGlyph()
        }
    }

    /// Category accent color — mapped onto the pastel palette so each
    /// category has a distinct but on-brand hue.
    private func categoryColor(_ cat: AchievementCategory) -> Color {
        switch cat {
        case .milestone: return DesignSystem.Colors.alpenglow
        case .weekly:    return DesignSystem.Colors.ember
        case .social:    return DesignSystem.Colors.glacierDeep
        case .explorer:  return DesignSystem.Colors.meadow
        }
    }

    // MARK: - Encouragement card (shown when 0 unlocked)

    private var encouragementCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image("hero-ready")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 130)

            Text("Your first achievement\nis one tour away")
                .font(DesignSystem.Typography.title2Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button { dismiss() } label: {
                Text("Start a tour")
                    .font(DesignSystem.Typography.bodyEmphasisInter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .background(Capsule().fill(DesignSystem.Colors.alpenglow))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(DesignSystem.Colors.alpenglowSoft)
        )
    }

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("What you can earn", count: locked.count)
            achievementsList(locked, dimmed: true)
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(DesignSystem.Typography.title3Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
            Text("\(count)")
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(DesignSystem.Colors.surfaceWarm))
            Spacer()
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private func achievementsList(_ list: [Achievement], dimmed: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(list) { achievement in
                AchievementRowCard(
                    achievement: achievement,
                    accent: categoryColor(achievement.category),
                    dimmed: dimmed
                )
            }
        }
    }
}

// MARK: - Achievement row card

fileprivate struct AchievementRowCard: View {
    let achievement: Achievement
    let accent: Color
    let dimmed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {

            ZStack {
                Circle()
                    .fill(dimmed ? DesignSystem.Colors.surfaceWarm : accent.opacity(0.18))
                    .frame(width: 48, height: 48)
                categoryGlyph(achievement.category)
                    .foregroundStyle(dimmed
                                     ? DesignSystem.Colors.inkWarm.opacity(0.45)
                                     : accent)
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(achievement.title)
                        .font(DesignSystem.Typography.bodyEmphasisInter)
                        .foregroundStyle(DesignSystem.Colors.inkWarm)
                        .lineLimit(1)
                    if !dimmed {
                        Text("Earned")
                            .font(DesignSystem.Typography.kickerInter)
                            .foregroundStyle(accent)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(accent.opacity(0.15)))
                    }
                }

                Text(achievement.description)
                    .font(DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
                    .lineLimit(2)

                if dimmed {
                    progressBar
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .opacity(dimmed ? 0.72 : 1.0)
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(DesignSystem.Colors.paperWarm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .stroke(
                    dimmed ? DesignSystem.Colors.borderSubtle : accent.opacity(0.3),
                    lineWidth: dimmed ? 0.5 : 1.0
                )
        )
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.Colors.surfaceWarm)
                        .frame(height: 4)
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * achievement.progress, height: 4)
                }
            }
            .frame(height: 4)

            Text(achievement.progressText)
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.55))
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func categoryGlyph(_ cat: AchievementCategory) -> some View {
        switch cat {
        case .milestone: MilestoneGlyph()
        case .weekly:    WeeklyGlyph()
        case .social:    SocialGlyph()
        case .explorer:  ExplorerGlyph()
        }
    }
}

#if DEBUG
#Preview("With unlocked") {
    AchievementsView()
        .environmentObject(AppState())
        .environmentObject(FeedViewModel())
        .environmentObject(LeaderboardViewModel())
}

#Preview("Empty (encouragement)") {
    AchievementsView()
        .environmentObject(AppState())
        .environmentObject(FeedViewModel())
        .environmentObject(LeaderboardViewModel())
}
#endif
