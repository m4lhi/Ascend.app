import SwiftUI
import Combine
import MapKit

// =========================================
// === DATEI: BasecampView.swift ===
// === Komoot-Style Social Feed Homepage ===
// =========================================



struct BasecampView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var leaderboardVM: LeaderboardViewModel
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
    @State private var showReadinessQuestionnaire = false
    @State private var showExtendedReadiness = false
    @State private var showAlpineWeather = false
    // Time-to-Go merged into Summit Readiness
    @State private var showCoachingGateway = false
    @State private var showElevationDetail = false
    @State private var showActiveGoalDetail = false
    @State private var showGoalsList = false
    @State private var showArena = false
    @State private var phase = false

    @ObservedObject private var weather = WeatherManager.shared

    private let bannerTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let accent = DesignSystem.Colors.accent
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    private var tierColor: Color {
        guard let profile = appState.ascendProfile else { return Color(red: 0.55, green: 0.37, blue: 0.22) }
        switch profile.ascend_tier.lowercased() {
        case "bronze":   return Color(red: 0.55, green: 0.37, blue: 0.22) // Warm bronze
        case "silver":   return Color(red: 0.62, green: 0.66, blue: 0.72)
        case "gold":     return Color(red: 0.86, green: 0.68, blue: 0.18)
        case "platinum": return Color(red: 0.55, green: 0.40, blue: 0.85)
        case "obsidian": return Color(red: 0.18, green: 0.12, blue: 0.26)
        default:         return Color(red: 0.55, green: 0.37, blue: 0.22)
        }
    }

    /// Companion shade for gradients — darker-desaturated cousin of `tierColor`.
    /// For Bronze we explicitly stay in the warm-brown family so the header no
    /// longer clashes with the logo blue.
    private var tierColorDeep: Color {
        guard let profile = appState.ascendProfile else { return Color(red: 0.32, green: 0.20, blue: 0.10) }
        switch profile.ascend_tier.lowercased() {
        case "bronze":   return Color(red: 0.32, green: 0.20, blue: 0.10)
        case "silver":   return Color(red: 0.36, green: 0.40, blue: 0.46)
        case "gold":     return Color(red: 0.55, green: 0.40, blue: 0.08)
        case "platinum": return Color(red: 0.30, green: 0.15, blue: 0.55)
        case "obsidian": return Color(red: 0.08, green: 0.05, blue: 0.14)
        default:         return Color(red: 0.32, green: 0.20, blue: 0.10)
        }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("bcScroll")).minY) { _, newValue in
                                handleScrollOffset(newValue)
                            }
                            .onAppear {
                                let initial = geo.frame(in: .named("bcScroll")).minY
                                scrollInitialOffset = initial
                                scrollLastOffset = initial
                            }
                    }
                    .frame(height: 0)

                    LazyVStack(spacing: 20) {

                        topBar
                            .padding(.top, 4)

                        rankCard
                            .padding(.horizontal, 16)

                        // DASHBOARD GRID
                        VStack(spacing: 16) {
                            readinessWidget

                            HStack(spacing: 14) {
                                aiCoachWidget
                                activityWidget
                            }

                            HStack(spacing: 14) {
                                elevationWidget
                                targetGoalWidget
                            }

                            alpineWeatherWidget
                        }
                        .padding(.horizontal, 16)

                        if !appState.suggestedRoutes.isEmpty {
                            suggestedRoutesSection
                                .padding(.top, 12)
                        }

                        Spacer().frame(height: 100)
                    }
                }
            }
            .coordinateSpace(name: "bcScroll")
            .refreshable {
                feedVM.fetchFeed(forceRefresh: true)
            }
        }
        .onAppear {
            feedVM.fetchFeed()
            appState.fetchRecommendedPeaks()
            appState.refreshReadiness()
            let lat = appState.activeMountain?.latitude ?? 45.8326
            let lon = appState.activeMountain?.longitude ?? 6.8652
            Task { await weather.fetchWeather(latitude: lat, longitude: lon) }
            withAnimation { phase = true }
        }
        .sheet(isPresented: $showXPDetails) {
            XPDetailView()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showObjectiveDetail) {
            if let obj = selectedObjective {
                ObjectiveDetailView(title: obj.title, icon: obj.icon, current: obj.current, target: obj.target, unit: obj.unit)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(36)
                    .adaptiveSheetBackground()
                    .presentationBackgroundInteraction(.enabled(upThrough: .large))
            }
        }
        .sheet(isPresented: $showAllActivities) {
            AllActivitiesView()
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .onChange(of: showTracker) { _, show in
            if show {
                appState.activeMountain = mountainToTrack
                withAnimation { appState.isTrackerActive = true }
                showTracker = false
            }
        }
        .sheet(isPresented: $showExtendedReadiness) {
            SummitReadinessExtendedView()
                .environmentObject(appState)
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showAlpineWeather) {
            AlpineWeatherMapView()
                .environmentObject(appState)
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showArena) {
            ArenaView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
        }
        .sheet(isPresented: $showGoalsList) {
            GoalsListView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
        }
        .sheet(isPresented: $showCoachingGateway) {
            AICoachingGatewayView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showElevationDetail) {
            ObjectiveDetailView(
                title: "Weekly Altitude",
                icon: "arrow.up.right",
                current: appState.weeklyElevation,
                target: 5000,
                unit: "m"
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(36)
            .adaptiveSheetBackground()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showActiveGoalDetail) {
            ObjectiveDetailView(
                title: appState.activeMountain?.name ?? "Active Goal",
                icon: "flag.checkered",
                current: 65,
                target: 100,
                unit: "% prepared"
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(36)
            .adaptiveSheetBackground()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
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
            .presentationCornerRadius(36)
            .adaptiveSheetBackground()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
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
    // MARK: - Rank Card (opens Arena sheet on tap)

    private var globalRank: Int? {
        let me = profileVM.userHandle.lowercased()
        guard !me.isEmpty else { return nil }
        let board = leaderboardVM.globalLeaderboard
        guard let idx = board.firstIndex(where: { $0.handle.lowercased() == me }) else { return nil }
        return idx + 1
    }

    private var tierLabel: String {
        (appState.ascendProfile?.ascend_tier ?? "Bronze").capitalized
    }

    private var rankCard: some View {
        Button {
            HapticManager.shared.light()
            showArena = true
        } label: {
            HStack(spacing: 14) {
                // Tier Disc — 3D dimensional gem
                ZStack {
                    // Base sphere
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tierColor, tierColorDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    // Top specular highlight (3D lit-from-above)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: UnitPoint(x: 0.30, y: 0.20),
                                startRadius: 0,
                                endRadius: 22
                            )
                        )
                        .frame(width: 50, height: 50)
                        .blendMode(.plusLighter)

                    // Inner darken bottom-right (depth shadow)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.clear, tierColorDeep.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 19, weight: .black))
                        .foregroundColor(.white)
                }


                VStack(alignment: .leading, spacing: 3) {
                    Text(tierLabel.uppercased())
                        .font(.appMono(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    if let rank = globalRank {
                        Text("Global Rank #\(rank)")
                            .font(.app(size: 17, weight: .heavy))
                    } else {
                        Text("\(appState.currentXP) XP · Lvl \(appState.currentLevel)")
                            .font(.app(size: 17, weight: .heavy))
                    }
                }
                Spacer()

                HStack(spacing: 6) {
                    Text("ARENA")
                        .font(.appMono(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(DesignSystem.Colors.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .ascentCard(cornerRadius: DesignSystem.Radius.xl)
        }
        .buttonStyle(AscentButtonStyle())
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            // Greeting + Avatar
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingLabel.uppercased())
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.58))
                        .tracking(1.8)
                    Text(profileVM.userName)
                        .font(.app(size: 26, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("LV \(appState.currentLevel) · \(appState.ascendProfile?.ascend_tier.uppercased() ?? "BRONZE")")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(0.8)
                }
                Spacer()
                // Avatar with animated XP ring
                Button {
                    HapticManager.shared.light()
                    appState.pendingTab = 3
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 3)
                            .frame(width: 52, height: 52)
                        Circle()
                            .trim(from: 0, to: phase ? Double(appState.currentLevelProgressXP) / Double(max(appState.xpNeededForNextLevel, 1)) : 0)
                            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.1).delay(0.35), value: phase)
                        if let urlString = profileVM.avatarURL, let url = URL(string: urlString) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.white.opacity(0.2))
                            }
                            .frame(width: 42, height: 42).clipShape(Circle())
                        } else {
                            Circle().fill(Color.white.opacity(0.9)).frame(width: 42, height: 42)
                                .overlay(Image(systemName: "person.fill").font(.app(size: 18)).foregroundColor(tierColorDeep))
                        }
                    }
                }
                .buttonStyle(PressableButtonStyle())
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
                .padding(.vertical, 14)

            // Stats row — XP / Streak / Level (Strava-style)
            HStack(spacing: 0) {
                heroStatCell(value: "\(appState.currentXP)", label: "XP", icon: "bolt.fill") { showXPDetails = true }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 38)
                heroStatCell(value: "\(appState.ascendProfile?.streak_days ?? 0)d", label: "STREAK", icon: "flame.fill") { appState.pendingTab = 3 }
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 38)
                heroStatCell(value: "LV \(appState.currentLevel)", label: "LEVEL", icon: "star.fill") { showXPDetails = true }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignSystem.Colors.accent)
                // Vertical highlight — top brighter, bottom darker (lit-from-above feel)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear, Color.black.opacity(0.20)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                // Specular bloom top-right — the "3D lit" hotspot
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.28), .clear],
                            center: UnitPoint(x: 0.85, y: 0),
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .blendMode(.plusLighter)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
        )
        
        
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private func heroStatCell(value: String, label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { HapticManager.shared.light(); action() }) {
            VStack(spacing: 4) {
                Text(value)
                    .font(.appMono(size: 20, weight: .black))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                    Text(label)
                        .font(.appMono(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(1.2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var greetingLabel: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5  { return "Night owl" }
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }


    // =========================================
    // MARK: - WIDGETS
    // =========================================

    private var readinessWidget: some View {
        Button {
            HapticManager.shared.light()
            showExtendedReadiness = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {

                // — Top label badge — Gentler Streak "Highlight" pill style
                HStack {
                    Text("SUMMIT READINESS")
                        .font(.appMono(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(1.4)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.white.opacity(0.18))
                        )
                    Spacer()
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }

                if let readiness = appState.readiness {
                    Spacer().frame(height: 22)

                    // — HERO score: huge percentage —
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(readiness.totalScore)")
                            .font(.app(size: 84, weight: .black))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.app(size: 36, weight: .black))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer().frame(height: 12)

                    // — Status title —
                    Text(readiness.status)
                        .font(.app(size: 26, weight: .black))
                        .foregroundColor(.white)

                    Spacer().frame(height: 8)

                    // — Recommendation —
                    Text(readiness.recommendation)
                        .font(.app(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    Spacer().frame(height: 18)

                    // — Sub-score pills (translucent on hero) —
                    HStack(spacing: 8) {
                        heroSubStat(label: "Physio",   score: readiness.physiologicalScore)
                        heroSubStat(label: "Load",     score: readiness.workloadScore)
                        heroSubStat(label: "Altitude", score: readiness.altitudeScore)
                    }

                    Spacer().frame(height: 16)

                    // — Weekly trend —
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WEEKLY TREND")
                            .font(.appMono(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                            .tracking(1.2)
                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { weekday in
                                weekdayPill(weekday: weekday)
                            }
                        }
                    }

                } else {
                    Spacer().frame(height: 22)
                    Text("?")
                        .font(.app(size: 84, weight: .black))
                        .foregroundColor(.white.opacity(0.55))

                    Spacer().frame(height: 12)
                    Text("Not assessed yet")
                        .font(.app(size: 22, weight: .black))
                        .foregroundColor(.white)

                    Spacer().frame(height: 6)
                    Text("Tap to complete the 20-question assessment")
                        .font(.app(size: 14))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(2)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(readinessHeroBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// Vivid 3D hero background — readiness color base + radial glow + specular sheen.
    /// Reads as a confident, dimensional surface (Gentler-Streak inspired).
    private var readinessHeroBackground: some View {
        ZStack {
            // Base — saturated readiness color
            readinessColor

            // Vertical depth — darker at bottom for grounded feel
            LinearGradient(
                colors: [Color.white.opacity(0.18), .clear, Color.black.opacity(0.18)],
                startPoint: .top, endPoint: .bottom
            )

            // Specular bloom — top-right radial highlight (the "3D lit-from-above" feel)
            RadialGradient(
                colors: [Color.white.opacity(0.32), .clear],
                center: UnitPoint(x: 0.85, y: 0.0),
                startRadius: 0,
                endRadius: 280
            )
            .blur(radius: 14)
            .blendMode(.plusLighter)

            // Subtle accent rim — bottom-left dim
            RadialGradient(
                colors: [Color.black.opacity(0.18), .clear],
                center: UnitPoint(x: 0.05, y: 1.05),
                startRadius: 0,
                endRadius: 240
            )
        }
    }

    /// Translucent stat pill that sits on the readiness hero card.
    private func heroSubStat(label: String, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.appMono(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.65))
                .tracking(1.0)
            Text("\(score)")
                .font(.app(size: 20, weight: .black))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var aiCoachWidget: some View {
        Button {
            HapticManager.shared.light()
            showCoachingGateway = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(colors: [accent.opacity(0.28), accent.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accent)
                            .symbolRenderingMode(.hierarchical)
                    }
                    Text("AI COACH")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(1.4)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accent.opacity(0.6))
                }
                Text(appState.readiness?.workloadScore ?? 0 > 80 ? "Push Today" : "Talk it out")
                    .font(.app(size: 18, weight: .black))
                    .foregroundColor(.white)
                Text("Training · Recovery · Nutrition")
                    .font(.app(size: 10))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ascentCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var elevationWidget: some View {
        Button {
            HapticManager.shared.light()
            showElevationDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(colors: [Color.green.opacity(0.28), Color.green.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.green)
                            .symbolRenderingMode(.hierarchical)
                    }
                    Text("ALTITUDE")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(1.4)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(appState.weeklyElevation)")
                        .font(.appMono(size: 30, weight: .black))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text("m")
                        .font(.appMono(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Text("This week")
                    .font(.app(size: 10))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ascentCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func weekdayPill(weekday: Int) -> some View {
        let score = appState.weeklyGoScores[weekday]
        let stage = score.map { appState.goStage(for: $0) }
        let isToday = Calendar.current.component(.weekday, from: Date()).mapISO == weekday
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(stage.map { goColor(for: $0) } ?? Color.white.opacity(0.22))
                .frame(height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isToday ? Color.white.opacity(0.85) : .clear, lineWidth: 1.2)
                )
            Text(weekdayLetter(weekday))
                .font(.appMono(size: 9, weight: .bold))
                .foregroundColor(isToday ? .white : .white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayLetter(_ iso: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][max(0, min(6, iso - 1))]
    }

    private func goColor(for stage: Int) -> Color {
        switch stage {
        case 0: return Color(red: 0.72, green: 0.16, blue: 0.16) // brick
        case 1: return Color(red: 0.90, green: 0.42, blue: 0.16) // terracotta
        case 2: return Color(red: 0.92, green: 0.62, blue: 0.12) // amber
        case 3: return Color(red: 0.10, green: 0.64, blue: 0.60) // alpine teal
        default: return Color(red: 0.08, green: 0.66, blue: 0.44) // emerald
        }
    }

    private var goVerdict: String {
        switch appState.goStage(for: appState.timeToGoScore) {
        case 0: return "Stand Down"
        case 1: return "High Risk"
        case 2: return "Proceed Cautiously"
        case 3: return "Green Light"
        default: return "Prime Window"
        }
    }

    private func relativeDateString(_ date: Date?) -> String {
        guard let date else { return "—" }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    private var activityWidget: some View {
        Button {
            HapticManager.shared.light()
            showAllActivities = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(colors: [Color.orange.opacity(0.28), Color.orange.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: "figure.hiking")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                            .symbolRenderingMode(.hierarchical)
                    }
                    Text("ACTIVITY")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(1.4)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(feedVM.recentTours.filter { $0.isCurrentUser }.count)")
                        .font(.appMono(size: 30, weight: .black))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text("Sessions")
                        .font(.appMono(size: 13, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Text("Total missions")
                    .font(.app(size: 10))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ascentCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// Smart selection: prefer active mountain → primary goal (next deadline) → first recommended peak
    private var primaryGoal: Goal? {
        if let active = appState.activeMountain { return Goal(from: active) }
        return appState.goals.primary
    }

    private var targetGoalWidget: some View {
        Button {
            HapticManager.shared.light()
            showGoalsList = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.goals.isEmpty ? "GOALS" : "NEXT GOAL")
                            .font(.appMono(size: 9, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .tracking(1.4)
                        Text(primaryGoal?.mountainName ?? "Add Goal")
                            .font(.app(size: 16, weight: .black))
                            .lineLimit(2)
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(colors: [accent.opacity(0.28), accent.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: appState.goals.isEmpty ? "plus" : "flag.2.crossed.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accent)
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                let readinessPct: Double = {
                    if let r = appState.readiness { return min(max(Double(r.totalScore) / 100.0, 0), 1) }
                    return 0
                }()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.12)).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(colors: [accent, accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: phase ? geo.size.width * readinessPct : 0, height: 5)
                            .animation(.easeOut(duration: 1.0).delay(0.4), value: phase)
                    }
                }
                .frame(height: 5)

                HStack {
                    if appState.readiness != nil {
                        Text("\(Int(readinessPct * 100))% ready")
                            .font(.appMono(size: 10, weight: .bold))
                            .foregroundColor(accent)
                    } else {
                        Text("Tap to plan")
                            .font(.appMono(size: 10, weight: .bold))
                            .foregroundColor(accent)
                    }
                    Spacer()
                    if let goal = primaryGoal, let date = goal.targetDate {
                        Text(date, format: .dateTime.month(.abbreviated).year())
                            .font(.appMono(size: 10, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    } else if appState.goals.count > 1 {
                        Text("\(appState.goals.count) goals")
                            .font(.appMono(size: 10, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ascentCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var alpineWeatherWidget: some View {
        let safetyColor: Color = {
            guard let w = weather.currentWeather else { return .blue }
            switch w.safetyLevel {
            case .good:    return .green
            case .caution: return .yellow
            case .warning: return .orange
            case .danger:  return .red
            }
        }()

        return Button {
            HapticManager.shared.light()
            showAlpineWeather = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(LinearGradient(colors: [safetyColor.opacity(0.28), safetyColor.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .symbolRenderingMode(.multicolor)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ALPINE SAFETY")
                                .font(.appMono(size: 9, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .tracking(1.4)
                            if let w = weather.currentWeather {
                                Text(w.safetyLevel.label)
                                    .font(.app(size: 13, weight: .black))
                                    .foregroundColor(safetyColor)
                            }
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        LivePulse()
                        Text("LIVE")
                            .font(.appMono(size: 8, weight: .bold))
                            .foregroundColor(.red)
                            .tracking(0.8)
                    }
                }

                HStack(spacing: 0) {
                    WeatherMetric(
                        icon: "wind",
                        value: weather.currentWeather.map { "\(Int($0.windSpeed))" } ?? "–",
                        label: "km/h"
                    )
                    WeatherMetric(
                        icon: "thermometer.low",
                        value: weather.currentWeather.map { "\(Int($0.temperature))°" } ?? "–",
                        label: "Temp"
                    )
                    WeatherMetric(
                        icon: "drop.fill",
                        value: weather.currentWeather.map { "\(Int($0.precipitationChance * 100))%" } ?? "–",
                        label: "Precip"
                    )
                    WeatherMetric(
                        icon: "eye",
                        value: weather.currentWeather.map { String(format: "%.0fkm", $0.visibility) } ?? "–",
                        label: "Vis."
                    )
                }
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("Open live weather map")
                        .font(.app(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ascentCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var readinessColor: Color {
        let score = appState.readiness?.totalScore ?? 0
        if score > 80 { return Color(red: 0.08, green: 0.66, blue: 0.44) }
        if score > 60 { return Color(red: 0.10, green: 0.64, blue: 0.60) }
        if score > 35 { return Color(red: 0.92, green: 0.62, blue: 0.12) }
        return Color(red: 0.80, green: 0.22, blue: 0.20)
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

    private func sectionHeader(_ title: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.app(size: 16, weight: .bold)).foregroundColor(iconColor)
            Text(title.uppercased()).font(.app(size: 14, weight: .black)).foregroundColor(DesignSystem.Colors.secondaryText).tracking(1)
            Spacer()
        }
        .padding(.horizontal, 16)
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
                .font(.app(size: 50)).foregroundColor(.white.opacity(0.08))
        }
    }
}

// =========================================
// MARK: - DASHBOARD COMPONENTS
// =========================================

struct ReadinessMiniStat: View {
    let label: String
    let score: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.app(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.1)).frame(height: 4)
                Capsule().fill(scoreColor).frame(width: CGFloat(score) / 100.0 * 40, height: 4)
            }
            .frame(width: 40)
        }
    }
    
    private var scoreColor: Color {
        if score > 80 { return .green }
        if score > 60 { return .orange }
        return .red
    }
}

struct WeatherMetric: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text(value)
                .font(.appMono(size: 13, weight: .black))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.appMono(size: 8, weight: .bold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Tiny pulsing red dot — signals "live data" next to anything real-time.
struct LivePulse: View {
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 6, height: 6)
            .scaleEffect(pulse ? 1.35 : 0.8)
            .opacity(pulse ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

/// Calendar's `.weekday` uses 1 = Sunday … 7 = Saturday. The week tracker uses
/// ISO (1 = Monday … 7 = Sunday). This tiny helper keeps the conversion local
/// so the call sites stay readable.
extension Int {
    var mapISO: Int {
        // 1 (Sun) → 7, 2 (Mon) → 1, … 7 (Sat) → 6
        return ((self + 5) % 7) + 1
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
                    .font(.app(size: 10, weight: .bold))
                    .foregroundColor(color)
                Text(title.uppercased())
                    .font(.app(size: 9, weight: .black))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .tracking(0.5)
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.app(size: 15, weight: .black))
                    .foregroundColor(.white)
                if let target {
                    Text(target)
                        .font(.app(size: 10))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 118)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                                    .font(.app(size: 6, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.trailing, 6)
                                    .padding(.bottom, 4)
                            }
                        }
                    }

                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.app(size: 8, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(mountain.difficulty.color)
                        .cornerRadius(4)
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mountain.name)
                        .font(.app(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(mountain.elevation)m · \(mountain.region)")
                        .font(.app(size: 11))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .frame(width: 180)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var routePlaceholder: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "mountain.2.fill").font(.app(size: 28)).foregroundColor(.white.opacity(0.12))
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(mountain.isPrestigePeak ? gold.opacity(0.15) : Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                        .font(.app(size: 18)).foregroundColor(mountain.isPrestigePeak ? gold : .blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(mountain.name).font(.app(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
                    Text("\(mountain.elevation)m · \(mountain.region)").font(.app(size: 11)).foregroundColor(.gray).lineLimit(1)
                }
                Spacer()
                Text(mountain.difficulty.rawValue.uppercased())
                    .font(.app(size: 8, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(mountain.difficulty.color)
                    .cornerRadius(4)
            }
            .padding(14)
            .frame(width: 260)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @State private var appeared = false
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Hero icon that pops in
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Circle()
                            .fill(accent.opacity(0.08))
                            .frame(width: 76, height: 76)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(accent)
                    }
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.05), value: appeared)
                    .padding(.top, 20)

                    VStack(spacing: 6) {
                        Text("\(appState.currentXP)")
                            .font(.app(size: 54, weight: .black))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        Text("XP")
                            .font(.appMono(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .tracking(2)
                        let region = profileVM.userRegion
                        Text(region.isEmpty || region == "Unknown" ? "Keep climbing to rank up!" : "Alpinist in \(region)")
                            .font(.app(size: 14))
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)

                    HStack(spacing: 12) {
                        glassStatCard(
                            icon: "arrow.up.right",
                            value: "\(feedVM.recentTours.filter{$0.isCurrentUser}.reduce(0){$0+$1.elevationGainMeters})",
                            unit: "m gained",
                            color: .green
                        )
                        glassStatCard(
                            icon: "figure.hiking",
                            value: "\(feedVM.recentTours.filter{$0.isCurrentUser}.count)",
                            unit: "missions",
                            color: .orange
                        )
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
        .background(.clear)
        .adaptiveSheetBackground()
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .onAppear { withAnimation { appeared = true } }
    }

    private func glassStatCard(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.appMono(size: 22, weight: .black))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(unit)
                .font(.appMono(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

struct StatColumn: View {
    let title: String; let value: String; let unit: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.app(.caption)).foregroundColor(.gray).textCase(.uppercase)
            Text(value).font(.app(.title2)).fontWeight(.bold)
            Text(unit).font(.app(.caption2)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// =========================================
// MARK: - All Activities
// =========================================

struct AllActivitiesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var feedVM: FeedViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(feedVM.recentTours) { tour in
                        ActivityCardView(tour: tour)
                            .padding(.horizontal, 16)
                            .onAppear {
                                if tour.id == feedVM.recentTours.last?.id {
                                    feedVM.loadNextFeedPage()
                                }
                            }
                    }
                    if feedVM.isLoadingMoreFeed {
                        ProgressView().tint(.gray).padding()
                    }
                    if !feedVM.hasMoreFeed && !feedVM.recentTours.isEmpty {
                        Text("You've seen it all!")
                            .font(.app(.caption))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .padding(.top, 10)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
            .navigationTitle("All Activities")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.app(size: 22))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
        }
        .background(.clear)
        .adaptiveSheetBackground()
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
}

// =========================================
// MARK: - Mountain Detail Preview Sheet
// =========================================

struct BasecampMountainDetailSheet: View {
    let mountain: Mountain
    let onStartTracking: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showProAnalysis = false
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        ZStack {
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
                        Image(systemName: "mountain.2.fill").font(.app(size: 40)).foregroundColor(Color.black.opacity(0.1))
                    }
                    
                    LinearGradient(colors: [.clear, Color(UIColor.systemBackground).opacity(0.85)], startPoint: .center, endPoint: .bottom)
                        .frame(height: 200)
                        
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.app(size: 28)).foregroundColor(.primary.opacity(0.6))
                            .background(Circle().fill(Color.white.opacity(0.8)))
                    }.padding(16)
                }.frame(height: 200)

                // Info Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mountain.name).font(.app(size: 24, weight: .bold)).foregroundColor(.white)
                            Text("\(mountain.region), \(mountain.country)").font(.app(size: 14)).foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        Spacer()
                        Text(mountain.difficulty.rawValue.uppercased())
                            .font(.app(size: 10, weight: .black))
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
                    .padding(.vertical, 14)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    if !mountain.description.isEmpty {
                        Text(mountain.description)
                            .font(.app(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
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
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                    
                    Spacer()
                    
                    // Pro Analysis: weather + avalanche + slope angle breakdown
                    Button { showProAnalysis = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                            Text("Pro Analysis")
                                .font(.app(size: 14, weight: .heavy))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "cloud.sun.fill")
                                Image(systemName: "exclamationmark.triangle.fill")
                                Image(systemName: "triangle.fill")
                            }
                            .font(.app(size: 11))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(DesignSystem.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(accent.opacity(0.4), lineWidth: 1.5)
                        )
                        .foregroundColor(.white)
                    }

                    Button {
                        onStartTracking()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Commence Mission")
                        }
                        .font(.app(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.bottom, 20)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .adaptiveSheetBackground()
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationCornerRadius(36)
        .sheet(isPresented: $showProAnalysis) {
            MountainProAnalysisSheet(mountain: mountain)
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
        }
    }

    private var estimatedDuration: String {
        let hours = Double(mountain.elevation) / 800.0
        if hours < 1 { return "\(Int(hours * 60))min" }
        return String(format: "%.0f-%.0fh", hours, hours * 1.3)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.app(size: 16)).foregroundColor(DesignSystem.Colors.secondaryText)
            Text(value).font(.app(size: 16, weight: .bold)).foregroundColor(.white)
            Text(label).font(.app(size: 11)).foregroundColor(DesignSystem.Colors.secondaryText)
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
            Text("\(level)").font(.app(size: 14, weight: .black)).foregroundColor(gold)
        }
    }
}

struct WeeklyObjectiveCard: View {
    let icon: String; let title: String; let current: Int; let target: Int; let unit: String; let color: Color
    private var progress: CGFloat { min(CGFloat(current) / CGFloat(max(target, 1)), 1.0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).font(.app(size: 14, weight: .bold)).foregroundColor(color)
                Spacer()
                Text("\(Int(progress * 100))%").font(.app(size: 11, weight: .bold)).foregroundColor(progress >= 1 ? .green : color)
            }
            Text(title.uppercased()).font(.app(size: 10, weight: .black)).foregroundColor(.gray).tracking(1)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(current)").font(.app(size: 24, weight: .black))
                Text("/ \(target) \(unit)").font(.app(size: 11, weight: .medium)).foregroundColor(.gray)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.1)).frame(height: 5)
                    Capsule().fill(color).frame(width: max(5, geo.size.width * progress), height: 5)
                }
            }.frame(height: 5)
        }
        .padding(16).frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface).cornerRadius(16)
    }
}

