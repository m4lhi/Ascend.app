import SwiftUI
import Combine

// =========================================
// === DATEI: BasecampView.swift ===
// === Social-First Homepage Redesign ===
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
    @State private var selectedFeedTab: FeedTab = .all

    private let bannerTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)
    private let cardBg = Color.white
    private let bg = Color(red: 0.95, green: 0.95, blue: 0.97)

    enum FeedTab: String, CaseIterable {
        case all = "All"
        case mine = "My Tours"
        case friends = "Friends"
    }

    private var filteredTours: [Tour] {
        switch selectedFeedTab {
        case .all: return appState.recentTours
        case .mine: return appState.recentTours.filter { $0.isCurrentUser }
        case .friends: return appState.recentTours.filter { !$0.isCurrentUser }
        }
    }

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

            // Soft ambient blobs
            Circle()
                .fill(RadialGradient(colors: [Color.blue.opacity(0.1), Color.clear], center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)
                .ignoresSafeArea()
            Circle()
                .fill(RadialGradient(colors: [Color.cyan.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: 125))
                .frame(width: 250, height: 250)
                .offset(x: 120, y: 100)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {

                    // ============================================
                    // MARK: - HEADER
                    // ============================================
                    headerSection
                        .padding(.bottom, 16)

                    // ============================================
                    // MARK: - QUICK STATS BAR
                    // ============================================
                    quickStatsBar
                        .padding(.bottom, 20)

                    // ============================================
                    // MARK: - FEED TAB SWITCHER + SOCIAL FEED
                    // ============================================
                    feedSection
                        .padding(.bottom, 24)

                    // ============================================
                    // MARK: - HERO BANNER
                    // ============================================
                    if !appState.recommendedPeaks.isEmpty {
                        heroBannerSection
                            .padding(.bottom, 24)
                    }

                    // ============================================
                    // MARK: - SUGGESTED ROUTES
                    // ============================================
                    if !appState.suggestedRoutes.isEmpty {
                        suggestedRoutesSection
                            .padding(.bottom, 24)
                    }

                    // ============================================
                    // MARK: - DISCOVER + COLLECTIONS
                    // ============================================
                    if !appState.recommendedPeaks.isEmpty {
                        discoverSection
                            .padding(.bottom, 24)
                    }

                    if !appState.myCollections.isEmpty {
                        collectionsSection
                            .padding(.bottom, 24)
                    }

                    Spacer().frame(height: 100)
                }
            }
        }
        .onAppear {
            appState.fetchFeed()
            appState.fetchRecommendedPeaks()
        }
        .sheet(isPresented: $showXPDetails) {
            XPDetailView().presentationDetents([.medium, .large]).preferredColorScheme(.light)
        }
        .sheet(isPresented: $showObjectiveDetail) {
            if let obj = selectedObjective {
                ObjectiveDetailView(title: obj.title, icon: obj.icon, current: obj.current, target: obj.target, unit: obj.unit)
                    .presentationDetents([.medium, .large])
                    .preferredColorScheme(.light)
            }
        }
        .sheet(isPresented: $showAllActivities) {
            AllActivitiesView().preferredColorScheme(.light)
        }
        .fullScreenCover(isPresented: $showTracker, onDismiss: {
            appState.fetchFeed()
        }) {
            LiveRecordView(targetMountain: mountainToTrack)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            Button(action: { showXPDetails = true }) {
                ZStack {
                    Circle()
                        .stroke(tierColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: Double(appState.currentLevelProgressXP) / Double(max(appState.xpNeededForNextLevel, 1)))
                        .stroke(tierColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))

                    if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(cardBg)
                        }
                        .frame(width: 44, height: 44).clipShape(Circle())
                    } else {
                        Circle().fill(cardBg).frame(width: 44, height: 44)
                            .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                    }

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
                    .font(.system(.subheadline, design: .rounded)).foregroundColor(.gray)
                Text(appState.userName)
                    .font(.system(.title2, design: .rounded)).fontWeight(.bold).foregroundColor(.primary)
            }
            .padding(.leading, 8)

            Spacer()

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
        .padding(.horizontal, 20).padding(.top, 16)
    }

    // MARK: - Quick Stats Bar (replaces weekly objectives for compact look)

    private var quickStatsBar: some View {
        HStack(spacing: 10) {
            // Weekly elevation
            QuickStatPill(
                icon: "arrow.up.right",
                value: "\(appState.weeklyElevation)",
                unit: "m",
                label: "This Week",
                progress: min(CGFloat(appState.weeklyElevation) / 5000.0, 1.0),
                color: gold
            )
            .onTapGesture {
                selectedObjective = ("Iron Legs", "figure.walk", appState.weeklyElevation, 5000, "meters")
                showObjectiveDetail = true
            }

            // Weekly summits
            QuickStatPill(
                icon: "mountain.2.fill",
                value: "\(appState.weeklyTourCount)",
                unit: "peaks",
                label: "Summits",
                progress: min(CGFloat(appState.weeklyTourCount) / 3.0, 1.0),
                color: .cyan
            )
            .onTapGesture {
                selectedObjective = ("Explorer", "mountain.2.fill", appState.weeklyTourCount, 3, "peaks")
                showObjectiveDetail = true
            }

            // Total tours
            QuickStatPill(
                icon: "flame.fill",
                value: "\(appState.recentTours.filter { $0.isCurrentUser }.count)",
                unit: "total",
                label: "Missions",
                progress: nil,
                color: .orange
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Feed Section (primary content)

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Tab bar + See All
            HStack {
                // Feed filter tabs
                HStack(spacing: 4) {
                    ForEach(FeedTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedFeedTab = tab
                            }
                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedFeedTab == tab ? gold.opacity(0.15) : Color.clear)
                                .foregroundColor(selectedFeedTab == tab ? gold : .secondary)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                if filteredTours.count > 5 {
                    Button(action: { showAllActivities = true }) {
                        HStack(spacing: 3) {
                            Text("All")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(gold)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Feed content
            if filteredTours.isEmpty && !appState.isLoadingMoreFeed {
                emptyFeedView
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(filteredTours.prefix(5))) { tour in
                        ActivityCardView(tour: tour)
                    }

                    if appState.isLoadingMoreFeed {
                        ProgressView().tint(.gray).padding()
                    }

                    if filteredTours.count > 5 {
                        Button(action: { showAllActivities = true }) {
                            HStack(spacing: 8) {
                                Text("View all \(filteredTours.count) activities")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(gold.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(gold.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyFeedView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gold.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "figure.hiking")
                    .font(.system(size: 32, design: .rounded))
                    .foregroundColor(gold)
            }

            Text(selectedFeedTab == .all ? "No activity yet" : "No \(selectedFeedTab.rawValue.lowercased()) activity")
                .font(.system(.headline, design: .rounded)).foregroundColor(.primary)
            Text(selectedFeedTab == .all
                 ? "Start your first mission to build your feed!"
                 : "Activities will appear here.")
                .font(.system(.caption, design: .rounded)).foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(40)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .light)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 15, y: 6)
    }

    // MARK: - Hero Banner

    private var heroBannerSection: some View {
        VStack(spacing: 10) {
            let peak = appState.recommendedPeaks[heroBannerIndex % appState.recommendedPeaks.count]

            Button {
                mountainToTrack = peak
                showTracker = true
            } label: {
                ZStack(alignment: .bottomLeading) {
                    Color.clear
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            Group {
                                if let urlString = peak.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        heroBannerPlaceholder(peak: peak)
                                    }
                                } else {
                                    heroBannerPlaceholder(peak: peak)
                                }
                            }
                        )
                        .clipped()

                    LinearGradient(colors: [.clear, .clear, .black.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(peak.isPrestigePeak ? "PRESTIGE PEAK" : "FEATURED")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(peak.isPrestigePeak ? gold : .cyan)
                                .tracking(2)
                            Text(peak.name)
                                .font(.system(.title3, design: .rounded)).fontWeight(.bold).foregroundColor(.white)
                            Text("\(peak.elevation)m · \(peak.region)")
                                .font(.system(.caption, design: .rounded)).foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 28)).foregroundColor(.white.opacity(0.5))
                    }
                    .padding(16)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)
            .id(heroBannerIndex)
            .transition(.opacity)
            .onReceive(bannerTimer) { _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    heroBannerIndex += 1
                }
            }

            HStack(spacing: 5) {
                ForEach(0..<min(appState.recommendedPeaks.count, 8), id: \.self) { i in
                    Capsule()
                        .fill(i == heroBannerIndex % appState.recommendedPeaks.count ? gold : Color.gray.opacity(0.2))
                        .frame(width: i == heroBannerIndex % appState.recommendedPeaks.count ? 16 : 5, height: 4)
                        .animation(.spring(response: 0.35), value: heroBannerIndex)
                }
            }
        }
    }

    // MARK: - Suggested Routes

    private var suggestedRoutesSection: some View {
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
    }

    // MARK: - Discover

    private var discoverSection: some View {
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
    }

    // MARK: - Collections

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("My Collections", icon: "rectangle.stack.fill", iconColor: .indigo)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.myCollections) { collection in
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                LinearGradient(
                                    colors: [Color.indigo.opacity(0.4), Color.blue.opacity(0.2)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(width: 140, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text(collection.name)
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .lineLimit(1)
                            Text("\(collection.mountain_ids.count) peaks")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 140)
                    }
                }
                .padding(.horizontal, 20)
            }
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
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
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
                .font(.system(size: 60, design: .rounded)).foregroundColor(.white.opacity(0.06))
        }
    }
}

// =========================================
// MARK: - Quick Stat Pill (new compact design)
// =========================================

struct QuickStatPill: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let progress: CGFloat?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(0.5)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.1)).frame(height: 4)
                        Capsule().fill(color)
                            .frame(width: max(4, geo.size.width * progress), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .light)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: color.opacity(0.1), radius: 8, y: 4)
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
                ZStack(alignment: .topTrailing) {
                    Color.clear
                        .frame(width: 180, height: 100)
                        .overlay(
                            Group {
                                if let urlString = mountain.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        routePlaceholder
                                    }
                                } else {
                                    routePlaceholder
                                }
                            }
                        )
                        .clipped()

                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(mountain.difficulty.color)
                        .cornerRadius(4)
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mountain.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                        Text("\(mountain.elevation)m")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        Text("·").foregroundColor(.gray.opacity(0.5))
                        Text(mountain.region)
                            .font(.system(size: 11, design: .rounded)).foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    if mountain.isPrestigePeak {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill").font(.system(size: 8))
                            Text("PRESTIGE").font(.system(size: 8, weight: .black, design: .rounded)).tracking(0.5)
                        }
                        .foregroundColor(gold)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .frame(width: 180)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .light)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
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
                .font(.system(size: 28, design: .rounded)).foregroundColor(.white.opacity(0.15))
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
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mountain.isPrestigePeak ? gold.opacity(0.15) : Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundColor(mountain.isPrestigePeak ? gold : .blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mountain.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(mountain.elevation)m · \(mountain.region)")
                        .font(.system(size: 11, design: .rounded)).foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text(mountain.difficulty.rawValue.uppercased())
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(mountain.difficulty.color)
                    .cornerRadius(4)
            }
            .padding(12)
            .frame(width: 260)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .light)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
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
            Color.clear.ignoresSafeArea()
            VStack(spacing: 30) {
                HStack {
                    Text("Performance Stats").font(.system(.title2, design: .rounded)).fontWeight(.bold).foregroundColor(.primary)
                    Spacer()
                    Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 24, design: .rounded)).foregroundColor(.gray) }
                }
                VStack(spacing: 8) {
                    Text("\(appState.currentXP) XP").font(.system(size: 48, weight: .black, design: .rounded)).foregroundColor(.primary)
                    Text(regionText).font(.system(.subheadline, design: .rounded)).foregroundColor(.green)
                }
                .padding(.vertical, 20)
                HStack(spacing: 20) {
                    StatColumn(title: "Elevation", value: "\(appState.recentTours.filter{$0.isCurrentUser}.reduce(0){$0 + $1.elevationGainMeters})", unit: "m")
                    Divider().background(Color.gray.opacity(0.3)).frame(height: 50)
                    StatColumn(title: "Missions", value: "\(appState.recentTours.filter{$0.isCurrentUser}.count)", unit: "total")
                }
                .padding()
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.06), radius: 20, y: 10)

                Spacer()
            }
            .padding(25)
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

struct StatColumn: View {
    let title: String; let value: String; let unit: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.system(.caption, design: .rounded)).foregroundColor(.gray).textCase(.uppercase)
            Text(value).font(.system(.title2, design: .rounded)).fontWeight(.bold).foregroundColor(.primary)
            Text(unit).font(.system(.caption2, design: .rounded)).foregroundColor(.gray)
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
                Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()

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
                            ProgressView().tint(.gray).padding()
                        }

                        if !appState.hasMoreFeed && !appState.recentTours.isEmpty {
                            Text("You've seen it all!")
                                .font(.system(.caption, design: .rounded)).foregroundColor(.gray)
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
                            .font(.system(size: 24, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// Keep old structs for backward compat
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

// =========================================
// MARK: - Weekly Objective Card (legacy, still used in ObjectiveDetailView)
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
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(progress >= 1 ? .green : color)
            }

            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.gray).tracking(1)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(current)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("/ \(target) \(unit)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.1)).frame(height: 5)
                    Capsule().fill(color)
                        .frame(width: max(5, geo.size.width * progress), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .light)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: color.opacity(0.15), radius: 12, y: 6)
    }
}
