import SwiftUI
import Combine

// =========================================
// === DATEI: BasecampView.swift ===
// === Social Dashboard — Premium Redesign ===
// =========================================

struct BasecampView: View {
    @EnvironmentObject var appState: AppState
    @State private var showXPDetails = false
    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil
    @State private var heroBannerIndex = 0
    @State private var showObjectiveDetail = false
    @State private var selectedObjective: (title: String, icon: String, current: Int, target: Int, unit: String)?
    @State private var showAllActivities = false

    private let bannerTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let cardBg = Color(red: 0.11, green: 0.11, blue: 0.14)
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.08)

    var ironLegsProgress: CGFloat {
        min(CGFloat(appState.weeklyElevation) / 5000.0, 1.0)
    }

    private var tierColor: Color {
        guard let profile = appState.ascendProfile else { return Color(red: 0.8, green: 0.45, blue: 0.15) }
        switch profile.ascend_tier.lowercased() {
        case "bronze": return Color(red: 0.8, green: 0.45, blue: 0.15)
        case "silver": return Color(red: 0.7, green: 0.75, blue: 0.8)
        case "gold": return Color(red: 0.95, green: 0.8, blue: 0.2)
        case "platinum": return Color(red: 0.7, green: 0.5, blue: 0.95)
        case "obsidian": return Color(red: 0.2, green: 0.1, blue: 0.3)
        default: return Color(red: 0.8, green: 0.45, blue: 0.15)
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ============================================
                    // MARK: - HEADER
                    // ============================================
                    HStack(alignment: .center) {
                        // Avatar with rank ring
                        Button(action: { showXPDetails = true }) {
                            ZStack {
                                // Rank ring
                                Circle()
                                    .stroke(tierColor.opacity(0.3), lineWidth: 3)
                                    .frame(width: 52, height: 52)
                                Circle()
                                    .trim(from: 0, to: Double(appState.currentLevelProgressXP) / Double(max(appState.xpNeededForNextLevel, 1)))
                                    .stroke(tierColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 52, height: 52)
                                    .rotationEffect(.degrees(-90))

                                if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Circle().fill(cardBg)
                                        }
                                    }
                                    .frame(width: 44, height: 44).clipShape(Circle())
                                } else {
                                    Circle().fill(cardBg).frame(width: 44, height: 44)
                                        .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                                }

                                // Level badge bottom-right
                                Text("\(appState.currentLevel)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(tierColor)
                                    .clipShape(Capsule())
                                    .offset(x: 16, y: 18)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good \(greeting)")
                                .font(.subheadline).foregroundColor(.gray)
                            Text(appState.userName)
                                .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        }
                        .padding(.leading, 8)

                        Spacer()

                        // XP pill
                        Button(action: { showXPDetails = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(appState.currentXP) XP")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(gold)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(gold.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)

                    // ============================================
                    // MARK: - WEEKLY OBJECTIVES (prominent cards)
                    // ============================================
                    VStack(alignment: .leading, spacing: 14) {
                        sectionHeader("This Week", icon: "flame.fill", iconColor: .orange)

                        HStack(spacing: 12) {
                            WeeklyObjectiveCard(
                                icon: "arrow.up.right",
                                title: "Elevation",
                                current: appState.weeklyElevation,
                                target: 5000,
                                unit: "m",
                                color: gold
                            )
                            .onTapGesture {
                                selectedObjective = ("Iron Legs", "figure.walk", appState.weeklyElevation, 5000, "meters")
                                showObjectiveDetail = true
                            }

                            WeeklyObjectiveCard(
                                icon: "mountain.2.fill",
                                title: "Summits",
                                current: appState.weeklyTourCount,
                                target: 3,
                                unit: "peaks",
                                color: .cyan
                            )
                            .onTapGesture {
                                selectedObjective = ("Explorer", "mountain.2.fill", appState.weeklyTourCount, 3, "peaks")
                                showObjectiveDetail = true
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 28)

                    // ============================================
                    // MARK: - HERO BANNER (auto-rotating)
                    // ============================================
                    if !appState.recommendedPeaks.isEmpty {
                        VStack(spacing: 10) {
                            let peak = appState.recommendedPeaks[heroBannerIndex % appState.recommendedPeaks.count]

                            Button {
                                mountainToTrack = peak
                                showTracker = true
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    // Background
                                    Color.clear
                                        .frame(height: 190)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Group {
                                                if let urlString = peak.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                                    AsyncImage(url: url) { phase in
                                                        if let image = phase.image {
                                                            image.resizable().scaledToFill()
                                                        } else {
                                                            heroBannerPlaceholder(peak: peak)
                                                        }
                                                    }
                                                } else {
                                                    heroBannerPlaceholder(peak: peak)
                                                }
                                            }
                                        )
                                        .clipped()

                                    // Gradient overlay
                                    LinearGradient(colors: [.clear, .clear, .black.opacity(0.85)],
                                                   startPoint: .top, endPoint: .bottom)

                                    // Text content
                                    HStack(alignment: .bottom) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(peak.isPrestigePeak ? "PRESTIGE PEAK" : "FEATURED")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundColor(peak.isPrestigePeak ? gold : .cyan)
                                                .tracking(2)
                                            Text(peak.name)
                                                .font(.title3).fontWeight(.bold).foregroundColor(.white)
                                            Text("\(peak.elevation)m · \(peak.region)")
                                                .font(.caption).foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(16)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 20)
                            .id(heroBannerIndex)
                            .transition(.opacity)
                            .onReceive(bannerTimer) { _ in
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    heroBannerIndex += 1
                                }
                            }

                            // Dots
                            HStack(spacing: 5) {
                                ForEach(0..<min(appState.recommendedPeaks.count, 8), id: \.self) { i in
                                    Capsule()
                                        .fill(i == heroBannerIndex % appState.recommendedPeaks.count ? gold : Color.white.opacity(0.2))
                                        .frame(width: i == heroBannerIndex % appState.recommendedPeaks.count ? 16 : 5, height: 4)
                                        .animation(.spring(response: 0.35), value: heroBannerIndex)
                                }
                            }
                        }
                        .padding(.bottom, 28)
                    }

                    // ============================================
                    // MARK: - SUGGESTED ROUTES (uniform cards)
                    // ============================================
                    if !appState.suggestedRoutes.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Suggested Routes", icon: "signpost.right.fill", iconColor: .green)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(appState.suggestedRoutes) { mountain in
                                        RouteCard(mountain: mountain) {
                                            mountainToTrack = mountain
                                            showTracker = true
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 28)
                    }

                    // ============================================
                    // MARK: - DISCOVER PEAKS (uniform grid cards)
                    // ============================================
                    if !appState.recommendedPeaks.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Discover", icon: "sparkle", iconColor: .purple)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(appState.recommendedPeaks) { mountain in
                                        DiscoverCard(mountain: mountain) {
                                            mountainToTrack = mountain
                                            showTracker = true
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 28)
                    }

                    // ============================================
                    // MARK: - RECENT ACTIVITY (social feed)
                    // ============================================
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            sectionHeader("Recent Activity", icon: "person.2.fill", iconColor: .blue)
                            Spacer()
                            if appState.recentTours.count > 3 {
                                Button(action: { showAllActivities = true }) {
                                    Text("See All")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(gold)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        if appState.recentTours.isEmpty && !appState.isLoadingMoreFeed {
                            VStack(spacing: 14) {
                                Image(systemName: "figure.hiking")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray.opacity(0.4))
                                Text("No activity yet")
                                    .font(.headline).foregroundColor(.white)
                                Text("Complete your first mission to see it here.")
                                    .font(.caption).foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(40)
                            .background(cardBg).cornerRadius(20)
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(Array(appState.recentTours.prefix(3))) { tour in
                                    ActivityCardView(tour: tour)
                                }
                                if appState.isLoadingMoreFeed && appState.recentTours.count < 3 {
                                    ProgressView().tint(.white).padding()
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 28)

                    Spacer().frame(height: 100)
                }
            }
        }
        .onAppear {
            appState.fetchFeed()
            appState.fetchRecommendedPeaks()
        }
        .sheet(isPresented: $showXPDetails) {
            XPDetailView().presentationDetents([.medium, .large]).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showObjectiveDetail) {
            if let obj = selectedObjective {
                ObjectiveDetailView(title: obj.title, icon: obj.icon, current: obj.current, target: obj.target, unit: obj.unit)
                    .presentationDetents([.medium, .large])
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showAllActivities) {
            AllActivitiesView().preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showTracker, onDismiss: {
            appState.fetchFeed()
        }) {
            LiveRecordView(targetMountain: mountainToTrack)
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "morning" }
        if hour < 17 { return "afternoon" }
        return "evening"
    }

    private func sectionHeader(_ title: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func heroBannerPlaceholder(peak: Mountain) -> some View {
        ZStack {
            LinearGradient(
                colors: peak.isPrestigePeak
                    ? [gold.opacity(0.3), Color(red: 0.12, green: 0.08, blue: 0.02)]
                    : [Color.blue.opacity(0.2), Color(red: 0.05, green: 0.05, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: peak.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                .font(.system(size: 60)).foregroundColor(.white.opacity(0.06))
        }
    }
}

// =========================================
// MARK: - Weekly Objective Card (redesigned)
// =========================================

struct WeeklyObjectiveCard: View {
    let icon: String
    let title: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color

    private var progress: CGFloat {
        min(CGFloat(current) / CGFloat(max(target, 1)), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(progress >= 1 ? .green : color)
            }

            Text(title.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.gray).tracking(1)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(current)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("/ \(target) \(unit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                    Capsule().fill(color)
                        .frame(width: max(5, geo.size.width * progress), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(progress >= 1 ? 0.4 : 0.1), lineWidth: 1)
        )
    }
}

// =========================================
// MARK: - Route Card (uniform size)
// =========================================

struct RouteCard: View {
    let mountain: Mountain
    var onTap: () -> Void

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image area — fixed height, gradient fallback
                ZStack(alignment: .topTrailing) {
                    Color.clear
                        .frame(width: 180, height: 100)
                        .overlay(
                            Group {
                                if let urlString = mountain.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            routePlaceholder
                                        }
                                    }
                                } else {
                                    routePlaceholder
                                }
                            }
                        )
                        .clipped()

                    // Difficulty pill
                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(mountain.difficulty.color)
                        .cornerRadius(4)
                        .padding(8)
                }

                // Info area
                VStack(alignment: .leading, spacing: 4) {
                    Text(mountain.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                        Text("\(mountain.elevation)m")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Text("·").foregroundColor(.gray.opacity(0.5))
                        Text(mountain.region)
                            .font(.system(size: 11)).foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    if mountain.isPrestigePeak {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill").font(.system(size: 8))
                            Text("PRESTIGE").font(.system(size: 8, weight: .black)).tracking(0.5)
                        }
                        .foregroundColor(gold)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .frame(width: 180)
            .background(Color(red: 0.11, green: 0.11, blue: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var routePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 28)).foregroundColor(.white.opacity(0.15))
        }
    }
}

// =========================================
// MARK: - Discover Card (compact, uniform)
// =========================================

struct DiscoverCard: View {
    let mountain: Mountain
    var onTap: () -> Void

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mountain.isPrestigePeak ? gold.opacity(0.15) : Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(mountain.isPrestigePeak ? gold : .blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mountain.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(mountain.elevation)m · \(mountain.region)")
                        .font(.system(size: 11)).foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text(mountain.difficulty.rawValue.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(mountain.difficulty.color)
                    .cornerRadius(4)
            }
            .padding(12)
            .frame(width: 260)
            .background(Color(red: 0.11, green: 0.11, blue: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(mountain.isPrestigePeak ? gold.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// =========================================
// MARK: - XP Detail Popup
// =========================================

struct XPDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    private var regionText: String {
        let region = appState.userRegion
        if region.isEmpty || region == "Unknown" {
            return "Keep climbing to rank up!"
        }
        return "Alpinist in \(region)"
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea()
            VStack(spacing: 30) {
                HStack {
                    Text("Performance Stats").font(.title2).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.gray) }
                }
                VStack(spacing: 8) {
                    Text("\(appState.currentXP) XP").font(.system(size: 48, weight: .black, design: .rounded)).foregroundColor(.white)
                    Text(regionText).font(.subheadline).foregroundColor(.green)
                }
                .padding(.vertical, 20)
                HStack(spacing: 20) {
                    StatColumn(title: "Elevation", value: "\(appState.recentTours.filter{$0.isCurrentUser}.reduce(0){$0 + $1.elevationGainMeters})", unit: "m")
                    Divider().background(Color.gray.opacity(0.3)).frame(height: 50)
                    StatColumn(title: "Missions", value: "\(appState.recentTours.filter{$0.isCurrentUser}.count)", unit: "total")
                }
                .padding().background(Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(16)
                Spacer()
            }
            .padding(25)
        }
    }
}

struct StatColumn: View {
    let title: String; let value: String; let unit: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.gray).textCase(.uppercase)
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(.white)
            Text(unit).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// =========================================
// MARK: - All Activities Full-Screen View
// =========================================

struct AllActivitiesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(appState.recentTours) { tour in
                            ActivityCardView(tour: tour)
                                .onAppear {
                                    if tour.id == appState.recentTours.last?.id {
                                        appState.loadMoreFeed()
                                    }
                                }
                        }

                        if appState.isLoadingMoreFeed {
                            ProgressView().tint(.white).padding()
                        }

                        if !appState.hasMoreFeed && !appState.recentTours.isEmpty {
                            Text("You've seen it all!")
                                .font(.caption).foregroundColor(.gray)
                                .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("All Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// Keep old structs for backward compat (unused but referenced elsewhere)
struct LevelBadge: View {
    let level: Int; let progress: Double
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 3).frame(width: 42, height: 42)
            Circle().trim(from: 0, to: progress).stroke(gold, style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 42, height: 42).rotationEffect(.degrees(-90))
            Text("\(level)").font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(gold)
        }
    }
}
