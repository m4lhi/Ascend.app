import SwiftUI
import Combine
import MapKit

// =========================================
// === DATEI: BasecampView.swift ===
// === Komoot-Style Social Feed Homepage ===
// =========================================



struct BasecampView: View {
    @EnvironmentObject var appState: AppState
    @State private var showXPDetails = false
    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil
    @State private var mountainDetailToShow: Mountain? = nil
    @State private var scrollInitialOffset: CGFloat? = nil
    @State private var scrollLastOffset: CGFloat = 0
    @State private var scrollAccDown: CGFloat = 0
    @State private var scrollAccUp: CGFloat = 0
    @State private var heroBannerIndex = 0
    @State private var showObjectiveDetail = false
    @State private var selectedObjective: (title: String, icon: String, current: Int, target: Int, unit: String)?
    @State private var showAllActivities = false

    private let bannerTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let accent = DesignSystem.Colors.accent
    private let bg = Color(red: 0.945, green: 0.945, blue: 0.96)
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

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
                ZStack(alignment: .top) {
                    // Invisible scroll-position tracker pinned at the top of content
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("bcScroll")).minY) { _, newValue in
                                handleScrollOffset(newValue)
                            }
                            .onAppear {
                                // Capture initial position
                                let initial = geo.frame(in: .named("bcScroll")).minY
                                scrollInitialOffset = initial
                                scrollLastOffset = initial
                            }
                    }
                    .frame(height: 0)
                    
                    LazyVStack(spacing: 0) {

                        // ============================
                        // MARK: - FEED DASHBOARD HEADER
                        // ============================
                        topBar
                            .padding(.top, 4)
                            .padding(.bottom, 14)

                        // ============================
                        // MARK: - SOCIAL FEED
                        // ============================
                        feedSectionHeader
                            .padding(.bottom, 12)

                        feedContent

                        // ============================
                        // MARK: - DISCOVER SECTION (after feed)
                        // ============================
                        if !appState.suggestedRoutes.isEmpty {
                            suggestedRoutesSection
                                .padding(.top, 32)
                        }

                        Spacer().frame(height: 100)
                    }
                }
            }
            .coordinateSpace(name: "bcScroll")
            .refreshable {
                appState.fetchFeed(forceRefresh: true)
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
        .onChange(of: showTracker) { _, show in
            if show {
                appState.activeMountain = mountainToTrack
                withAnimation { appState.isTrackerActive = true }
                showTracker = false // reset local state
            }
        }
        .sheet(item: $mountainDetailToShow) { mountain in
            BasecampMountainDetailSheet(mountain: mountain) {
                mountainDetailToShow = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    mountainToTrack = mountain
                    showTracker = true
                }
            }
            .presentationDetents([.fraction(0.85), .large])
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Scroll-based FAB visibility
    private func handleScrollOffset(_ newOffset: CGFloat) {
        // First call: record initial position
        if scrollInitialOffset == nil {
            scrollInitialOffset = newOffset
            scrollLastOffset = newOffset
            return
        }
        
        let delta = newOffset - scrollLastOffset
        scrollLastOffset = newOffset
        
        // Near the top? Always show FAB
        if newOffset >= (scrollInitialOffset! - 15) {
            scrollAccDown = 0
            scrollAccUp = 0
            if !appState.isFABVisible {
                withAnimation(.easeOut(duration: 0.25)) { appState.isFABVisible = true }
            }
            return
        }
        
        if delta < -2 {
            // Scrolling DOWN
            scrollAccDown += abs(delta)
            scrollAccUp = 0
            if scrollAccDown > 50 && appState.isFABVisible {
                withAnimation(.easeOut(duration: 0.25)) { appState.isFABVisible = false }
            }
        } else if delta > 2 {
            // Scrolling UP
            scrollAccUp += delta
            scrollAccDown = 0
            if scrollAccUp > 25 && !appState.isFABVisible {
                withAnimation(.easeOut(duration: 0.25)) { appState.isFABVisible = true }
            }
        }
    }

    // =========================================
    // MARK: - Top Bar
    // =========================================
    private var topBar: some View {
        ZStack(alignment: .topLeading) {
            // Hero gradient background – logo palette
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DesignSystem.Colors.logoGradient)
                .overlay(
                    // Soft bloom
                    RadialGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        center: .topTrailing,
                        startRadius: 10, endRadius: 260
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: DesignSystem.Colors.accent.opacity(0.28), radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .tracking(1.2)
                        Text(appState.userName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(action: { showXPDetails = true }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 2)
                                .frame(width: 46, height: 46)
                            Circle()
                                .trim(from: 0, to: Double(appState.currentLevelProgressXP) / Double(max(appState.xpNeededForNextLevel, 1)))
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 46, height: 46)
                                .rotationEffect(.degrees(-90))
                            if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.white.opacity(0.25))
                                }
                                .frame(width: 38, height: 38).clipShape(Circle())
                            } else {
                                Circle().fill(Color.white).frame(width: 38, height: 38)
                                    .overlay(Image(systemName: "person.fill").font(.system(size: 16)).foregroundColor(DesignSystem.Colors.accent))
                            }
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                HStack(spacing: 10) {
                    heroStatChip(icon: "bolt.fill", value: "\(appState.currentXP)", label: "XP")
                    heroStatChip(icon: "arrow.up.right", value: "\(appState.weeklyElevation)m", label: "This week")
                    heroStatChip(icon: "flame.fill", value: "\(appState.ascendProfile?.streak_days ?? 0)", label: "Streak")
                }
            }
            .padding(18)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func heroStatChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .opacity(0.75)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(
            Capsule().fill(Color.white.opacity(0.18))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        )
    }

    // =========================================
    // MARK: - Weekly Strip (compact horizontal stats)
    // =========================================
    private var weeklyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                WeekPill(icon: "arrow.up.right", title: "Elevation", value: "\(appState.weeklyElevation)m", target: "/ 5,000m", progress: min(CGFloat(appState.weeklyElevation) / 5000.0, 1.0), color: accent)
                    .onTapGesture {
                        selectedObjective = ("Elevation", "figure.walk", appState.weeklyElevation, 5000, "meters")
                        showObjectiveDetail = true
                    }

                WeekPill(icon: "mountain.2.fill", title: "Summits", value: "\(appState.weeklyTourCount)", target: "/ 3", progress: min(CGFloat(appState.weeklyTourCount) / 3.0, 1.0), color: .cyan)
                    .onTapGesture {
                        selectedObjective = ("Summits", "mountain.2.fill", appState.weeklyTourCount, 3, "peaks")
                        showObjectiveDetail = true
                    }

                WeekPill(icon: "flame.fill", title: "Streak", value: "\(appState.ascendProfile?.streak_days ?? 0)d", target: nil, progress: nil, color: .orange)

                // Total missions
                let myTourCount = appState.recentTours.filter { $0.isCurrentUser }.count
                WeekPill(icon: "flag.fill", title: "Total", value: "\(myTourCount)", target: "tours", progress: nil, color: .green)
            }
            .padding(.horizontal, 16)
        }
    }

    // =========================================
    // MARK: - Featured Peak Card
    // =========================================
    private var featuredPeak: some View {
        let peak = appState.recommendedPeaks[heroBannerIndex % appState.recommendedPeaks.count]
        return Button {
            mountainDetailToShow = peak
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Image
                Color.clear
                    .frame(height: 160)
                    .overlay(
                        Group {
                            if let urlString = peak.effectiveImageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                    placeholder: { peakPlaceholder(peak) }
                            } else {
                                peakPlaceholder(peak)
                            }
                        }
                    )
                    .clipped()

                // Gradient
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)

                // Text
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        if peak.isPrestigePeak {
                            Text("PRESTIGE PEAK")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(accent).tracking(1.5)
                        }
                        Text(peak.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(peak.elevation)m · \(peak.region)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PlainButtonStyle())
        .id(heroBannerIndex)
        .onReceive(bannerTimer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) { heroBannerIndex += 1 }
        }
    }

    // =========================================
    // MARK: - Feed Section Header (minimalist)
    // =========================================
    private var feedSectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Recent Activity")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            if !appState.recentTours.isEmpty {
                Text("\(appState.recentTours.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    // =========================================
    // MARK: - Feed Content
    // =========================================
    @ViewBuilder
    private var feedContent: some View {
        if appState.recentTours.isEmpty && !appState.isLoadingMoreFeed {
            emptyFeed
                .padding(.horizontal, 16)
                .padding(.top, 20)
        } else {
            LazyVStack(spacing: 12) {
                let toursWithIndex = Array(appState.recentTours.enumerated())
                ForEach(toursWithIndex, id: \.element.id) { index, tour in
                    ActivityCardView(tour: tour)
                        .padding(.horizontal, 16)
                        .onAppear {
                            // Infinite scroll
                            if tour.id == appState.recentTours.last?.id {
                                appState.loadMoreFeed()
                            }
                        }
                        
                    // Inject a single featured peak after the very first item to introduce discovery naturally
                    if index == 0, !appState.recommendedPeaks.isEmpty {
                        featuredPeak
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                    }
                }

                if appState.isLoadingMoreFeed {
                    ProgressView()
                        .tint(.gray)
                        .padding(.vertical, 20)
                }

                if !appState.hasMoreFeed && !appState.recentTours.isEmpty {
                    Text("You're all caught up!")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 16)
                }
            }
        }
    }

    private var emptyFeed: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))

            Text("No activity yet")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)

            Text("Start your first mission or follow other alpinists to build your feed.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Suggested Routes Section
    private var suggestedRoutesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Suggested Routes", icon: "signpost.right.fill", iconColor: .green)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.suggestedRoutes) { mountain in
                        RouteCard(mountain: mountain) {
                            mountainDetailToShow = mountain
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(iconColor)
            Text(title.uppercased()).font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(.secondary).tracking(1)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    @ViewBuilder
    private func peakPlaceholder(_ peak: Mountain) -> some View {
        ZStack {
            LinearGradient(
                colors: peak.isPrestigePeak
                    ? [accent.opacity(0.3), Color(red: 0.15, green: 0.1, blue: 0.05)]
                    : [Color.blue.opacity(0.2), Color(red: 0.08, green: 0.08, blue: 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: peak.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                .font(.system(size: 50)).foregroundColor(.white.opacity(0.08))
        }
    }
}

// =========================================
// MARK: - Week Pill
// =========================================

struct WeekPill: View {
    let icon: String
    let title: String
    let value: String
    let target: String?
    let progress: CGFloat?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                if let target {
                    Text(target)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.12)).frame(height: 3)
                        Capsule().fill(color)
                            .frame(width: max(3, geo.size.width * progress), height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(width: 108)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: color.opacity(0.06), radius: 4, y: 2)
    }
}

// =========================================
// MARK: - Route Card
// =========================================

struct RouteCard: View {
    let mountain: Mountain
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Color.clear
                        .frame(width: 180, height: 100)
                        .overlay(
                            Group {
                                if let urlString = mountain.effectiveImageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
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
                        
                    if let credit = mountain.image_credit, !credit.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Foto: \(credit)")
                                    .font(.system(size: 6, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.trailing, 6)
                                    .padding(.bottom, 4)
                            }
                        }
                    }

                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(mountain.difficulty.color)
                        .cornerRadius(4)
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mountain.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(mountain.elevation)m · \(mountain.region)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .frame(width: 180)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var routePlaceholder: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "mountain.2.fill").font(.system(size: 28)).foregroundColor(.white.opacity(0.12))
        }
    }
}

// =========================================
// MARK: - Discover Card
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
                        .font(.system(size: 18)).foregroundColor(mountain.isPrestigePeak ? gold : .blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(mountain.name).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary).lineLimit(1)
                    Text("\(mountain.elevation)m · \(mountain.region)").font(.system(size: 11, design: .rounded)).foregroundColor(.gray).lineLimit(1)
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
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
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

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 30) {
                HStack {
                    Text("Performance Stats").font(.system(.title2, design: .rounded)).fontWeight(.bold)
                    Spacer()
                    Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.gray) }
                }
                VStack(spacing: 8) {
                    Text("\(appState.currentXP) XP").font(.system(size: 48, weight: .black, design: .rounded))
                    let region = appState.userRegion
                    Text(region.isEmpty || region == "Unknown" ? "Keep climbing to rank up!" : "Alpinist in \(region)")
                        .font(.system(.subheadline, design: .rounded)).foregroundColor(.green)
                }
                .padding(.vertical, 20)
                HStack(spacing: 20) {
                    StatColumn(title: "Elevation", value: "\(appState.recentTours.filter{$0.isCurrentUser}.reduce(0){$0 + $1.elevationGainMeters})", unit: "m")
                    Divider().frame(height: 50)
                    StatColumn(title: "Missions", value: "\(appState.recentTours.filter{$0.isCurrentUser}.count)", unit: "total")
                }
                .padding()
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
            Text(value).font(.system(.title2, design: .rounded)).fontWeight(.bold)
            Text(unit).font(.system(.caption2, design: .rounded)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// =========================================
// MARK: - Micro-interaction Button Style
// =========================================
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.92
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// =========================================
// MARK: - All Activities
// =========================================

struct AllActivitiesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.945, green: 0.945, blue: 0.96).ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.recentTours) { tour in
                            ActivityCardView(tour: tour)
                                .padding(.horizontal, 16)
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
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("All Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// =========================================
// MARK: - Mountain Detail Preview Sheet
// =========================================

struct BasecampMountainDetailSheet: View {
    let mountain: Mountain
    let onStartTracking: () -> Void
    @Environment(\.dismiss) var dismiss
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Image
                ZStack(alignment: .topTrailing) {
                    if let urlStr = mountain.effectiveImageUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(white: 0.9)
                        }.frame(height: 200).clipped()
                    } else {
                        Color(white: 0.9).frame(height: 200)
                        Image(systemName: "mountain.2.fill").font(.system(size: 40)).foregroundColor(Color.black.opacity(0.1))
                    }
                    
                    LinearGradient(colors: [.clear, .white], startPoint: .center, endPoint: .bottom)
                        .frame(height: 200)
                        
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.primary.opacity(0.6))
                            .background(Circle().fill(Color.white.opacity(0.8)))
                    }.padding(16)
                }.frame(height: 200)

                // Info Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mountain.name).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.primary)
                            Text("\(mountain.region), \(mountain.country)").font(.system(size: 14, design: .rounded)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(mountain.difficulty.rawValue.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(mountain.difficulty.color)
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 0) {
                        statItem(icon: "arrow.up.right", value: "\(mountain.elevation)m", label: "Elevation")
                        statItem(icon: "chart.line.uptrend.xyaxis", value: "~\(mountain.elevation / 2)m", label: "Est. Gain")
                        statItem(icon: "clock", value: estimatedDuration, label: "Est. Time")
                    }
                    .padding(.vertical, 12)
                    .background(Color(white: 0.95))
                    .cornerRadius(12)
                    
                    if !mountain.description.isEmpty {
                        Text(mountain.description)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                    
                    if let lat = mountain.latitude, let lon = mountain.longitude {
                        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Map(position: .constant(.region(MKCoordinateRegion(center: center, latitudinalMeters: 4000, longitudinalMeters: 4000))), interactionModes: []) {
                            if let routeStr = mountain.routes?.first?.route_polyline {
                                let coords = PolylineUtility.decode(polyline: routeStr)
                                if !coords.isEmpty {
                                    MapPolyline(coordinates: coords)
                                        .stroke(accent, lineWidth: 4)
                                }
                            }
                            Marker(mountain.name, coordinate: center)
                                .tint(gold)
                        }
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.9), lineWidth: 1))
                    }
                    
                    Spacer()
                    
                    Button {
                        onStartTracking()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Commence Mission")
                        }
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: gold.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.bottom, 20)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var estimatedDuration: String {
        let hours = Double(mountain.elevation) / 800.0
        if hours < 1 { return "\(Int(hours * 60))min" }
        return String(format: "%.0f-%.0fh", hours, hours * 1.3)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(.secondary)
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
            Text(label).font(.system(size: 11, design: .rounded)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Backward compat
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

struct WeeklyObjectiveCard: View {
    let icon: String; let title: String; let current: Int; let target: Int; let unit: String; let color: Color
    private var progress: CGFloat { min(CGFloat(current) / CGFloat(max(target, 1)), 1.0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(color)
                Spacer()
                Text("\(Int(progress * 100))%").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(progress >= 1 ? .green : color)
            }
            Text(title.uppercased()).font(.system(size: 10, weight: .black, design: .rounded)).foregroundColor(.gray).tracking(1)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(current)").font(.system(size: 24, weight: .black, design: .rounded))
                Text("/ \(target) \(unit)").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.gray)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.1)).frame(height: 5)
                    Capsule().fill(color).frame(width: max(5, geo.size.width * progress), height: 5)
                }
            }.frame(height: 5)
        }
        .padding(16).frame(maxWidth: .infinity)
        .background(Color.white).cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 8, y: 4)
    }
}
