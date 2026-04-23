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
    @State private var showReadinessQuestionnaire = false
    @State private var showExtendedReadiness = false
    @State private var showAlpineWeather = false
    // Time-to-Go merged into Summit Readiness
    @State private var showCoachingGateway = false
    @State private var showElevationDetail = false
    @State private var showActiveGoalDetail = false
    @State private var phase = false

    @ObservedObject private var weather = WeatherManager.shared

    private let bannerTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let accent = DesignSystem.Colors.accent
    private let bg = Color(red: 0.945, green: 0.945, blue: 0.96)
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
            bg.ignoresSafeArea()

            // Tier-colored hero wash at top
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [tierColor.opacity(0.18), bg.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 260)
                .ignoresSafeArea(edges: .top)
                Spacer()
            }

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
                            .opacity(phase ? 1 : 0)
                            .offset(y: phase ? 0 : 24)
                            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.02), value: phase)

                        // DASHBOARD GRID
                        VStack(spacing: 16) {
                            readinessWidget
                                .opacity(phase ? 1 : 0)
                                .offset(y: phase ? 0 : 28)
                                .animation(.spring(response: 0.52, dampingFraction: 0.8).delay(0.08), value: phase)

                            HStack(spacing: 14) {
                                aiCoachWidget
                                activityWidget
                            }
                            .opacity(phase ? 1 : 0)
                            .offset(y: phase ? 0 : 28)
                            .animation(.spring(response: 0.52, dampingFraction: 0.8).delay(0.14), value: phase)

                            HStack(spacing: 14) {
                                elevationWidget
                                targetGoalWidget
                            }
                            .opacity(phase ? 1 : 0)
                            .offset(y: phase ? 0 : 28)
                            .animation(.spring(response: 0.52, dampingFraction: 0.8).delay(0.20), value: phase)

                            alpineWeatherWidget
                                .opacity(phase ? 1 : 0)
                                .offset(y: phase ? 0 : 28)
                                .animation(.spring(response: 0.52, dampingFraction: 0.8).delay(0.26), value: phase)
                        }
                        .padding(.horizontal, 16)

                        if !appState.suggestedRoutes.isEmpty {
                            suggestedRoutesSection
                                .padding(.top, 12)
                                .opacity(phase ? 1 : 0)
                                .offset(y: phase ? 0 : 28)
                                .animation(.spring(response: 0.52, dampingFraction: 0.8).delay(0.32), value: phase)
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
                .presentationBackground(.ultraThinMaterial)
.presentationBackgroundInteraction(.enabled(upThrough: .large))

        }
        .sheet(isPresented: $showObjectiveDetail) {
            if let obj = selectedObjective {
                ObjectiveDetailView(title: obj.title, icon: obj.icon, current: obj.current, target: obj.target, unit: obj.unit)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(36)
                    .presentationBackground(.ultraThinMaterial)
.presentationBackgroundInteraction(.enabled(upThrough: .large))

            }
        }
        .sheet(isPresented: $showAllActivities) {
            AllActivitiesView()
                .presentationCornerRadius(36)
                .presentationBackground(.ultraThinMaterial)
.presentationBackgroundInteraction(.enabled(upThrough: .large))

        }
        .onChange(of: showTracker) { _, show in
            if show {
                appState.activeMountain = mountainToTrack
                withAnimation { appState.isTrackerActive = true }
                showTracker = false // reset local state
            }
        }
        .sheet(isPresented: $showExtendedReadiness) {
            SummitReadinessExtendedView()
                .environmentObject(appState)
                .presentationCornerRadius(36)
                .presentationBackground(.ultraThinMaterial)
.presentationBackgroundInteraction(.enabled(upThrough: .large))

        }
        .sheet(isPresented: $showAlpineWeather) {
            AlpineWeatherMapView()
                .environmentObject(appState)
                .presentationCornerRadius(36)
                .presentationBackground(.ultraThinMaterial)
.presentationBackgroundInteraction(.enabled(upThrough: .large))

        }
        // Time-to-Go questionnaire merged into SummitReadinessExtendedView
        .sheet(isPresented: $showCoachingGateway) {
            AICoachingGatewayView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .presentationBackground(.ultraThinMaterial)
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
            .presentationBackground(.ultraThinMaterial)
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
            .presentationBackground(.ultraThinMaterial)
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
            .presentationBackground(.ultraThinMaterial)
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
    private var topBar: some View {
        VStack(spacing: 0) {
            // Greeting + Avatar
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingLabel.uppercased())
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.58))
                        .tracking(1.8)
                    Text(appState.userName)
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
                        if let urlString = appState.avatarURL, let url = URL(string: urlString) {
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
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [tierColor, tierColorDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                // Gloss highlight top-left
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        startPoint: .topLeading, endPoint: .center
                    ))
            }
            .shadow(color: tierColorDeep.opacity(0.38), radius: 18, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private func heroStatCell(value: String, label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { HapticManager.shared.light(); action() }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
                Text(value)
                    .font(.appMono(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.appMono(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.48))
                    .tracking(1.2)
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
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUMMIT READINESS")
                            .font(.appMono(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                        Text(appState.readiness?.status ?? "Start Assessment")
                            .font(.app(size: 20, weight: .bold))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: CGFloat(appState.readiness?.totalScore ?? 0) / 100.0)
                            .stroke(readinessColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.9), value: appState.readiness?.totalScore)

                        Text("\(appState.readiness?.totalScore ?? 0)")
                            .font(.appMono(size: 15, weight: .bold))
                    }
                    .frame(width: 54, height: 54)
                }

                if let readiness = appState.readiness {
                    Text(readiness.recommendation)
                        .font(.app(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        ReadinessMiniStat(label: "Physio", score: readiness.physiologicalScore)
                        ReadinessMiniStat(label: "Load", score: readiness.workloadScore)
                        ReadinessMiniStat(label: "Altitude", score: readiness.altitudeScore)
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    Text("WEEKLY TREND")
                        .font(.appMono(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                        
                    // Weekly tracker — 7 capsules, each coloured by the stored go-stage
                    // for that weekday. Empty weekdays stay neutral-grey.
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { weekday in
                            weekdayPill(weekday: weekday)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.app(size: 12))
                        Text("Tap to complete 20-question assessment")
                            .font(.app(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.app(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ascentCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var aiCoachWidget: some View {
        Button {
            HapticManager.shared.light()
            showCoachingGateway = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(accent.opacity(0.12)).frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(accent)
                    }
                    Text("AI COACH")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.4)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accent.opacity(0.6))
                }
                Text(appState.readiness?.workloadScore ?? 0 > 80 ? "Push Today" : "Talk it out")
                    .font(.app(size: 18, weight: .black))
                    .foregroundColor(.primary)
                Text("Training · Recovery · Nutrition")
                    .font(.app(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    DesignSystem.Colors.cardBackground
                    LinearGradient(colors: [accent.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .shadow(color: accent.opacity(0.10), radius: 10, y: 4)
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
                        Circle().fill(Color.green.opacity(0.12)).frame(width: 28, height: 28)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    }
                    Text("ALTITUDE")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.4)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                (Text("\(appState.weeklyElevation)")
                    .font(.appMono(size: 22, weight: .black))
                    .foregroundColor(.primary)
                + Text(" m")
                    .font(.appMono(size: 13, weight: .bold))
                    .foregroundColor(.secondary))
                    .contentTransition(.numericText())
                Text("This week")
                    .font(.app(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    DesignSystem.Colors.cardBackground
                    LinearGradient(colors: [Color.green.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .shadow(color: Color.green.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }



    private func weekdayPill(weekday: Int) -> some View {
        let score = appState.weeklyGoScores[weekday]
        let stage = score.map { appState.goStage(for: $0) }
        let isToday = Calendar.current.component(.weekday, from: Date()).mapISO == weekday
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(stage.map { goColor(for: $0) } ?? Color.gray.opacity(0.18))
                .frame(height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isToday ? Color.primary.opacity(0.5) : .clear, lineWidth: 1.2)
                )
            Text(weekdayLetter(weekday))
                .font(.appMono(size: 9, weight: .bold))
                .foregroundColor(isToday ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayLetter(_ iso: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][max(0, min(6, iso - 1))]
    }

    private func goColor(for stage: Int) -> Color {
        switch stage {
        case 0: return Color(red: 0.70, green: 0.10, blue: 0.10) // deep red
        case 1: return Color(red: 0.92, green: 0.38, blue: 0.20) // red-orange
        case 2: return Color(red: 0.95, green: 0.78, blue: 0.18) // amber
        case 3: return Color(red: 0.45, green: 0.80, blue: 0.35) // light green
        default: return Color(red: 0.12, green: 0.58, blue: 0.28) // deep green
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
                        Circle().fill(Color.orange.opacity(0.12)).frame(width: 28, height: 28)
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    Text("ACTIVITY")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.4)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                (Text("\(appState.recentTours.filter { $0.isCurrentUser }.count)")
                    .font(.appMono(size: 22, weight: .black))
                    .foregroundColor(.primary)
                + Text(" Sessions")
                    .font(.appMono(size: 12, weight: .bold))
                    .foregroundColor(.secondary))
                    .contentTransition(.numericText())
                Text("Total missions")
                    .font(.app(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    DesignSystem.Colors.cardBackground
                    LinearGradient(colors: [Color.orange.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .shadow(color: Color.orange.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var targetGoalWidget: some View {
        Button {
            HapticManager.shared.light()
            showActiveGoalDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ACTIVE GOAL")
                            .font(.appMono(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.4)
                        Text(appState.activeMountain?.name ?? "Mont Blanc")
                            .font(.app(size: 16, weight: .black))
                            .lineLimit(2)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(accent.opacity(0.10)).frame(width: 30, height: 30)
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accent)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.12)).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(colors: [accent, accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: phase ? geo.size.width * 0.65 : 0, height: 5)
                            .animation(.easeOut(duration: 1.0).delay(0.4), value: phase)
                    }
                }
                .frame(height: 5)

                HStack {
                    Text("65% ready")
                        .font(.appMono(size: 10, weight: .bold))
                        .foregroundColor(accent)
                    Spacer()
                    Text("Aug 2026")
                        .font(.appMono(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    DesignSystem.Colors.cardBackground
                    LinearGradient(colors: [accent.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .shadow(color: accent.opacity(0.10), radius: 10, y: 4)
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
                            Circle().fill(safetyColor.opacity(0.12)).frame(width: 28, height: 28)
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(safetyColor)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ALPINE SAFETY")
                                .font(.appMono(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
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
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Open live weather map")
                        .font(.app(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    DesignSystem.Colors.cardBackground
                    LinearGradient(colors: [safetyColor.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .shadow(color: safetyColor.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var readinessColor: Color {
        let score = appState.readiness?.totalScore ?? 0
        if score > 80 { return .green }
        if score > 60 { return .orange }
        return .red
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
            Text(title.uppercased()).font(.app(size: 14, weight: .black)).foregroundColor(.secondary).tracking(1)
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
                .foregroundColor(.secondary)
            
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
                .foregroundColor(.secondary)
            Text(value)
                .font(.appMono(size: 13, weight: .black))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.appMono(size: 8, weight: .bold))
                .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.app(size: 15, weight: .black))
                    .foregroundColor(.primary)
                if let target {
                    Text(target)
                        .font(.app(size: 10))
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
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(mountain.elevation)m · \(mountain.region)")
                        .font(.app(size: 11))
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mountain.isPrestigePeak ? gold.opacity(0.15) : Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                        .font(.app(size: 18)).foregroundColor(mountain.isPrestigePeak ? gold : .blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(mountain.name).font(.app(size: 14, weight: .bold)).foregroundColor(.primary).lineLimit(1)
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
    @State private var appeared = false
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

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
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        Text("XP")
                            .font(.appMono(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(2)
                        let region = appState.userRegion
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
                            value: "\(appState.recentTours.filter{$0.isCurrentUser}.reduce(0){$0+$1.elevationGainMeters})",
                            unit: "m gained",
                            color: .green
                        )
                        glassStatCard(
                            icon: "figure.hiking",
                            value: "\(appState.recentTours.filter{$0.isCurrentUser}.count)",
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
        .presentationBackground(.ultraThinMaterial)
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
                .foregroundColor(.primary)
                .contentTransition(.numericText())
            Text(unit)
                .font(.appMono(size: 10, weight: .bold))
                .foregroundColor(.secondary)
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
            ScrollView(showsIndicators: false) {
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
                            .font(.app(.caption))
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .background(.clear)
        .presentationBackground(.ultraThinMaterial)
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
                            Text(mountain.name).font(.app(size: 24, weight: .bold)).foregroundColor(.primary)
                            Text("\(mountain.region), \(mountain.country)").font(.app(size: 14)).foregroundColor(.secondary)
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
                    .padding(.vertical, 12)
                    .background(Color(white: 0.95))
                    .cornerRadius(12)
                    
                    if !mountain.description.isEmpty {
                        Text(mountain.description)
                            .font(.app(size: 13))
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
                        .font(.app(size: 18, weight: .bold))
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
        .presentationBackground(.ultraThinMaterial)
.presentationBackgroundInteraction(.enabled(upThrough: .large))

        .presentationCornerRadius(36)
    }

    private var estimatedDuration: String {
        let hours = Double(mountain.elevation) / 800.0
        if hours < 1 { return "\(Int(hours * 60))min" }
        return String(format: "%.0f-%.0fh", hours, hours * 1.3)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.app(size: 16)).foregroundColor(.secondary)
            Text(value).font(.app(size: 16, weight: .bold)).foregroundColor(.primary)
            Text(label).font(.app(size: 11)).foregroundColor(.secondary)
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
        .background(Color.white).cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 8, y: 4)
    }
}

