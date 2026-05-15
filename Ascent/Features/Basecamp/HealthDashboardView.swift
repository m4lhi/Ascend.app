import SwiftUI

struct HealthDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var leaderboardVM: LeaderboardViewModel
    @EnvironmentObject var discoveryVM: DiscoveryViewModel
    @EnvironmentObject var readinessVM: ReadinessViewModel
    @StateObject private var healthData = HealthDataProvider.shared
    @ObservedObject private var weather = WeatherManager.shared
    @State private var showSettings = false
    @State private var showArena = false
    @State private var showExtendedReadiness = false
    @State private var showAlpineWeather = false
    @State private var showCoachingGateway = false
    @State private var showGoalsList = false
    @State private var showElevationDetail = false
    @State private var showAllActivities = false
    @State private var showTrophyRoom = false
    @State private var phase = false

    private let accent = DesignSystem.Colors.accent

    private var weekdayLabel: String {
        Date().formatted(.dateTime.weekday(.wide))
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.day().month(.wide))
    }

    private var tierColor: Color {
        guard let profile = appState.ascendProfile else { return Color(red: 0.55, green: 0.37, blue: 0.22) }
        switch profile.ascend_tier.lowercased() {
        case "bronze":   return Color(red: 0.55, green: 0.37, blue: 0.22)
        case "silver":   return Color(red: 0.62, green: 0.66, blue: 0.72)
        case "gold":     return Color(red: 0.86, green: 0.68, blue: 0.18)
        case "platinum": return Color(red: 0.55, green: 0.40, blue: 0.85)
        case "obsidian": return Color(red: 0.18, green: 0.12, blue: 0.26)
        default:         return Color(red: 0.55, green: 0.37, blue: 0.22)
        }
    }

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

    private var tierLabel: String {
        (appState.ascendProfile?.ascend_tier ?? "Bronze").capitalized
    }

    private var globalRank: Int? {
        let me = profileVM.userHandle.lowercased()
        guard !me.isEmpty else { return nil }
        guard let idx = leaderboardVM.globalLeaderboard.firstIndex(where: { $0.handle.lowercased() == me }) else { return nil }
        return idx + 1
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.paperWarm.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {

                    header
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)
                        .padding(.top, 4)

                    readinessHeroCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    rankCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    dashboardGrid
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    alpineWeatherWidget
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    trophyAccessCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    if !discoveryVM.suggestedRoutes.isEmpty {
                        suggestedRoutesSection
                    }

                    Spacer().frame(height: 120)
                }
            }
        }
        .cornerGlow(readinessGlowColor, intensity: 0.12, corner: .topLeading)
        .cornerGlow(.blue.opacity(0.5), intensity: 0.06, corner: .bottomTrailing)
        .task {
            await healthData.fetchAll()
            feedVM.fetchFeed()
            discoveryVM.fetchRecommendedPeaks()
            readinessVM.refresh()
            let lat = appState.activeMountain?.latitude ?? 45.8326
            let lon = appState.activeMountain?.longitude ?? 6.8652
            Task { await weather.fetchWeather(latitude: lat, longitude: lon) }
            withAnimation { phase = true }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
        }
        .sheet(isPresented: $showArena) {
            ArenaView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
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
        .sheet(isPresented: $showCoachingGateway) {
            AICoachingGatewayView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showGoalsList) {
            GoalsListView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
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
        .sheet(isPresented: $showAllActivities) {
            AllActivitiesView()
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showTrophyRoom) {
            TrophyRoomView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
        }
    }

    private var readinessGlowColor: Color {
        let score = readinessVM.readiness?.totalScore ?? 0
        return readinessColorFor(score)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("\(weekdayLabel), \(dateLabel)")
                    .font(DesignSystem.Typography.kickerInter)
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                Spacer()
                profileButton
            }
            Text(editorialTitle)
                .font(DesignSystem.Typography.title1Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
            Text(narrativeBody)
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }

    /// Editorial title — narrative, English, mood-driven from the
    /// current readiness score. Replaces the generic "Heute" header.
    private var editorialTitle: String {
        guard let score = readinessVM.readiness?.totalScore else {
            return "Take the day slow."
        }
        if score > 70 { return "You're ready for the mountain today." }
        if score > 45 { return "A measured day in the mountains." }
        return "Stay low today — your body asks for rest."
    }

    /// Narrative body — one or two sentences that explain the score in
    /// human terms. Uses the readiness recommendation (already English
    /// from ReadinessManager.calculate) plus an optional weather line.
    private var narrativeBody: String {
        guard let r = readinessVM.readiness else {
            return "Your numbers are still warming up. Give it a moment."
        }
        let weatherSnippet: String = {
            if let w = weather.currentWeather {
                let temp = Int(w.temperature.rounded())
                return " Today's window opens around \(temp)°."
            }
            return ""
        }()
        return r.recommendation + weatherSnippet
    }

    private var profileButton: some View {
        Button { showSettings = true } label: {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.inkWarm.opacity(0.12), lineWidth: 2)
                    .frame(width: 42, height: 42)
                Circle()
                    .trim(from: 0, to: phase ? Double(appState.currentLevelProgressXP) / Double(max(appState.xpNeededForNextLevel, 1)) : 0)
                    .stroke(DesignSystem.Colors.glacierDeep, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.1).delay(0.35), value: phase)
                if let urlString = profileVM.avatarURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Circle().fill(DesignSystem.Colors.inkWarm.opacity(0.10)) }
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(DesignSystem.Colors.glacierDeep.opacity(0.18))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DesignSystem.Colors.glacierDeep)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Readiness Hero Card (full-width, top of page)

    private var readinessHeroCard: some View {
        let score = readinessVM.readiness?.totalScore ?? 0
        let label = readinessVM.readiness?.status ?? "No data yet"
        let ratio = min(1.0, Double(score) / 100.0)
        let barColor = readinessColorFor(score)
        let ink = DesignSystem.Colors.inkOnSage

        return Button {
            HapticManager.shared.light()
            showExtendedReadiness = true
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(barColor.opacity(0.85))
                            Text("Summit readiness")
                                .font(DesignSystem.Typography.kickerInter)
                                .tracking(0.5)
                                .foregroundStyle(ink.opacity(0.62))
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundStyle(ink)
                                .contentTransition(.numericText())
                                .monospacedDigit()
                            Text("%")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(ink.opacity(0.55))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ink.opacity(0.45))
                        Spacer()
                        Text(label)
                            .font(DesignSystem.Typography.title3Inter)
                            .foregroundStyle(ink)
                    }
                }
                .padding(.bottom, 16)

                GeometryReader { geo in
                    let barWidth = phase ? geo.size.width * ratio : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ink.opacity(0.10))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(barColor)
                            .frame(width: barWidth)
                            .animation(.spring(response: 1.2, dampingFraction: 0.7), value: phase)
                    }
                }
                .frame(height: 10)

                if let readiness = readinessVM.readiness {
                    HStack(spacing: 8) {
                        readinessSubPill(label: "Physio", score: readiness.physiologicalScore)
                        readinessSubPill(label: "Load", score: readiness.workloadScore)
                        readinessSubPill(label: "Altitude", score: readiness.altitudeScore)
                    }
                    .padding(.top, 16)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12))
                        Text("Tap to assess your summit readiness")
                            .font(DesignSystem.Typography.bodyInter)
                    }
                    .foregroundStyle(ink.opacity(0.55))
                    .padding(.top, 14)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                    .fill(DesignSystem.Colors.sageCard)
            )
        }
        .buttonStyle(.plain)
    }

    private func readinessSubPill(label: String, score: Int) -> some View {
        let ink = DesignSystem.Colors.inkOnSage
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DesignSystem.Typography.kickerInter)
                .tracking(0.5)
                .foregroundStyle(ink.opacity(0.55))
            Text("\(score)")
                .font(DesignSystem.Typography.title3Inter)
                .foregroundStyle(ink)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ink.opacity(0.08))
        )
    }

    private func readinessColorFor(_ score: Int) -> Color {
        if score >= 80 { return DesignSystem.Colors.success }
        if score >= 60 { return DesignSystem.Colors.metricDuration }
        if score >= 40 { return DesignSystem.Colors.warning }
        if score > 0 { return DesignSystem.Colors.error }
        return DesignSystem.Colors.accent
    }

    // MARK: - Rank Card

    private var rankCard: some View {
        Button {
            HapticManager.shared.light()
            showArena = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tierColor, tierColorDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.45), .clear],
                                center: UnitPoint(x: 0.30, y: 0.20),
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 46, height: 46)
                        .blendMode(.plusLighter)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tierLabel.uppercased())
                        .font(.appMono(size: 9, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    if let rank = globalRank {
                        Text("Global Rank #\(rank)")
                            .font(.app(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                    } else {
                        Text("\(appState.currentXP) XP · Lvl \(appState.currentLevel)")
                            .font(.app(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
                Spacer()

                HStack(spacing: 6) {
                    Text("ARENA")
                        .font(.appMono(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(accent)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .pastelCard(.sand, applyForeground: false)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Dashboard Grid

    private var dashboardGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    HapticManager.shared.light()
                    showCoachingGateway = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(accent)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(accent.opacity(0.6))
                        }
                        Text("AI Coach")
                            .font(.app(size: 15, weight: .black))
                            .foregroundColor(.white)
                        Text("Training · Recovery")
                            .font(.appMono(size: 9, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .pastelCard(.sage, applyForeground: false)
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    HapticManager.shared.light()
                    showAllActivities = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "figure.hiking")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(feedVM.recentTours.filter { $0.isCurrentUser }.count)")
                                .font(.appMono(size: 24, weight: .black))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            Text("Sessions")
                                .font(.appMono(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .pastelCard(.ice, applyForeground: false)
                }
                .buttonStyle(PressableButtonStyle())
            }

            HStack(spacing: 14) {
                Button {
                    HapticManager.shared.light()
                    showElevationDetail = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.metricElevation)
                            Spacer()
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(appState.weeklyElevation)")
                                .font(.appMono(size: 24, weight: .black))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            Text("m")
                                .font(.appMono(size: 12, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        Text("Höhenmeter diese Woche")
                            .font(.appMono(size: 9, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .pastelCard(.sand, applyForeground: false)
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    HapticManager.shared.light()
                    showGoalsList = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: appState.goals.isEmpty ? "plus" : "flag.2.crossed.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        Text(appState.goals.first?.mountainName ?? "Ziel setzen")
                            .font(.app(size: 15, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        if let r = readinessVM.readiness {
                            Text("\(r.totalScore)% ready")
                                .font(.appMono(size: 10, weight: .bold))
                                .foregroundColor(accent)
                        } else {
                            Text("Tap to plan")
                                .font(.appMono(size: 10, weight: .bold))
                                .foregroundColor(accent)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .pastelCard(.ice, applyForeground: false)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Alpine Weather

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
                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .symbolRenderingMode(.multicolor)
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
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

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
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pastelCard(.ice, applyForeground: false)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Trophy Room Access

    private var trophyAccessCard: some View {
        Button {
            HapticManager.shared.light()
            showTrophyRoom = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.prestige)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements & Trophies")
                        .font(.app(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Badges, Milestones, Collections")
                        .font(.appMono(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .pastelCard(.sand, applyForeground: false)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Suggested Routes

    private var suggestedRoutesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RouteGlyph()
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                    .frame(width: 18, height: 18)
                Text("Recommended routes")
                    .font(DesignSystem.Typography.title2Inter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenInset)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(discoveryVM.suggestedRoutes) { mountain in
                        RouteCard(mountain: mountain) {}
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenInset)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Training Sparkline Card

struct TrainingSparkCard: View {
    let label: String
    let value: String
    let unit: String
    let data: [HealthDataPoint]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SparklineChart(data: data, color: color, height: 36, showDot: false, showGradientFill: true)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.appMono(size: 18, weight: .bold))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.appMono(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            Text(label)
                .font(.appMono(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(width: 110)
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.05), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.12), Color.white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Energy Mini Donut

struct EnergyMiniDonut: View {
    let active: Double
    let resting: Double

    private var activeRatio: Double {
        let total = active + resting
        return total > 0 ? active / total : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 4)
            Circle()
                .trim(from: 0, to: activeRatio)
                .stroke(
                    AngularGradient(
                        colors: [
                            DesignSystem.Colors.metricEnergy,
                            DesignSystem.Colors.metricEnergy.opacity(0.5),
                            DesignSystem.Colors.metricEnergy
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * activeRatio)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: activeRatio)
                .stroke(DesignSystem.Colors.metricEnergy.opacity(0.3), lineWidth: 8)
                .rotationEffect(.degrees(-90))
                .blur(radius: 4)
        }
        .frame(width: 36, height: 36)
    }
}
