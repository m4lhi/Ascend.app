import SwiftUI
import Combine

// =========================================
// === DATEI: BasecampView.swift ===
// === Social Dashboard mit Discovery ===
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

    var ironLegsProgress: CGFloat {
        min(CGFloat(appState.weeklyElevation) / 5000.0, 1.0)
    }

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    @ViewBuilder
    func bannerGradient(isPrestige: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: isPrestige
                    ? [gold.opacity(0.4), Color(red: 0.08, green: 0.08, blue: 0.12)]
                    : [Color.blue.opacity(0.3), Color(red: 0.08, green: 0.08, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: isPrestige ? "crown.fill" : "mountain.2.fill")
                .font(.system(size: 70)).foregroundColor(.white.opacity(0.07))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 30) {

                    // === HEADER mit Level-Badge ===
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BASECAMP").font(.caption).fontWeight(.bold).foregroundColor(.gray).tracking(1.5)
                            Text(appState.userName).font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                            if let firstSport = appState.selectedSports.first {
                                Text(firstSport).font(.caption).foregroundColor(.gray)
                            }
                        }
                        Spacer()

                        HStack(spacing: 12) {
                            Button(action: { showXPDetails = true }) {
                                LevelBadge(level: appState.currentLevel, progress: Double(appState.currentLevelProgressXP) / Double(appState.xpNeededForNextLevel))
                            }

                            if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Circle().fill(Color.gray.opacity(0.2))
                                    }
                                }
                                .frame(width: 50, height: 50).clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            } else {
                                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1).frame(width: 50, height: 50)
                                    .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 20)

                    // === HERO BANNER ===
                    if !appState.recommendedPeaks.isEmpty {
                        let peak = appState.recommendedPeaks[heroBannerIndex % appState.recommendedPeaks.count]
                        let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
                        Button {
                            mountainToTrack = peak
                            showTracker = true
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                if let urlString = peak.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            bannerGradient(isPrestige: peak.isPrestigePeak)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                                } else {
                                    bannerGradient(isPrestige: peak.isPrestigePeak)
                                }
                                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(peak.isPrestigePeak ? "PRESTIGE PEAK" : "RECOMMENDED")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(peak.isPrestigePeak ? gold : .cyan)
                                        .tracking(1.5)
                                    Text(peak.name)
                                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                                    Text("\(peak.elevation)m · \(peak.region)")
                                        .font(.caption).foregroundColor(.white.opacity(0.75))
                                }
                                .padding(18)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(height: 200)
                        .cornerRadius(20)
                        .clipped()
                        .padding(.horizontal, 20)
                        .onReceive(bannerTimer) { _ in
                            withAnimation(.easeInOut(duration: 0.5)) {
                                heroBannerIndex = (heroBannerIndex + 1) % appState.recommendedPeaks.count
                            }
                        }

                        // Dot indicators
                        HStack(spacing: 6) {
                            ForEach(0..<min(appState.recommendedPeaks.count, 5), id: \.self) { i in
                                Circle()
                                    .fill(i == heroBannerIndex % appState.recommendedPeaks.count ? gold : Color.white.opacity(0.3))
                                    .frame(width: i == heroBannerIndex % appState.recommendedPeaks.count ? 8 : 5, height: 5)
                                    .animation(.spring(response: 0.3), value: heroBannerIndex)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // === SUGGESTED ROUTES (Amazon Prime style, database peaks) ===
                    if !appState.suggestedRoutes.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Suggested Routes").font(.title3).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    Spacer().frame(width: 5)
                                    ForEach(appState.suggestedRoutes) { mountain in
                                        SuggestedRouteCard(mountain: mountain) {
                                            mountainToTrack = mountain
                                            showTracker = true
                                        }
                                    }
                                    Spacer().frame(width: 5)
                                }
                            }
                        }
                    }

                    // === DISCOVER ===
                    if !appState.recommendedPeaks.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Discover").font(.title3).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    Spacer().frame(width: 5)
                                    ForEach(appState.recommendedPeaks) { mountain in
                                        DiscoveryCard(mountain: mountain) {
                                            mountainToTrack = mountain
                                            showTracker = true
                                        }
                                    }
                                    Spacer().frame(width: 5)
                                }
                            }
                        }
                    }

                    // === WEEKLY OBJECTIVES (tappable, week-filtered) ===
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Weekly Objectives").font(.title3).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                Spacer().frame(width: 5)
                                ObjectiveCard(icon: "figure.walk", title: "Iron Legs", progress: "\(appState.weeklyElevation)M / 5,000M", percent: ironLegsProgress)
                                    .onTapGesture {
                                        selectedObjective = ("Iron Legs", "figure.walk", appState.weeklyElevation, 5000, "meters")
                                        showObjectiveDetail = true
                                    }
                                ObjectiveCard(icon: "mountain.2.fill", title: "Explorer", progress: "\(appState.weeklyTourCount)/3 PEAKS", percent: min(CGFloat(appState.weeklyTourCount) / 3.0, 1.0))
                                    .onTapGesture {
                                        selectedObjective = ("Explorer", "mountain.2.fill", appState.weeklyTourCount, 3, "peaks")
                                        showObjectiveDetail = true
                                    }
                                ObjectiveCard(icon: "lock.fill", title: "Altitude", progress: "LOCKED", percent: 0.0)
                                Spacer().frame(width: 5)
                            }
                        }
                    }

                    // === SOCIAL FEED (max 3 on dashboard) ===
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Recent Activity").font(.title3).fontWeight(.bold).foregroundColor(.white)
                            Spacer()
                            if appState.recentTours.count > 3 {
                                Button(action: { showAllActivities = true }) {
                                    HStack(spacing: 4) {
                                        Text("Show All")
                                            .font(.subheadline).fontWeight(.semibold)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                                }
                            }
                        }

                        if appState.recentTours.isEmpty && !appState.isLoadingMoreFeed {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.climbing").font(.system(size: 40)).foregroundColor(.gray.opacity(0.5))
                                Text("Your journey begins here.").font(.headline).foregroundColor(.white)
                                Text("Track your first mission to see your activity.").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(30).background(Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(20)
                        } else {
                            VStack(spacing: 20) {
                                ForEach(Array(appState.recentTours.prefix(3))) { tour in
                                    ActivityCardView(tour: tour)
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }

                                if appState.isLoadingMoreFeed && appState.recentTours.count < 3 {
                                    ProgressView().tint(.white).padding()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 120)
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
}

// === HERO BANNER VIEW (kept for reference, currently inlined in BasecampView) ===
struct HeroBannerView: View {
    let items: [HeroBannerItem]
    @Binding var index: Int
    var onTap: (Mountain?) -> Void

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        if items.isEmpty { EmptyView() } else {
            VStack(spacing: 10) {
                let item = items[min(index, items.count - 1)]
                HeroBannerSlide(item: item) { onTap(item.mountain) }
                    .id(item.id)
                    .frame(height: 200)
                    .cornerRadius(20)
                    .clipped()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                // Dot indicators
                HStack(spacing: 6) {
                    ForEach(0..<items.count, id: \.self) { i in
                        Circle()
                            .fill(i == index ? gold : Color.white.opacity(0.3))
                            .frame(width: i == index ? 8 : 5, height: i == index ? 8 : 5)
                            .animation(.spring(response: 0.3), value: index)
                    }
                }
            }
        }
    }
}

struct HeroBannerSlide: View {
    let item: HeroBannerItem
    var onTap: () -> Void

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    private var badgeColor: Color {
        item.badge == "PRESTIGE PEAK" ? gold : .cyan
    }

    private var gradientColors: [Color] {
        item.badge == "PRESTIGE PEAK"
            ? [gold.opacity(0.4), Color(red: 0.08, green: 0.08, blue: 0.12)]
            : [Color.blue.opacity(0.3), Color(red: 0.08, green: 0.08, blue: 0.12)]
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Background: photo or gradient
                if let urlString = item.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        } else {
                            gradientBackground
                        }
                    }
                } else {
                    gradientBackground
                }

                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 5) {
                    if let badge = item.badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(badgeColor)
                            .tracking(1.5)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(badgeColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text(item.title)
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        .shadow(radius: 2)
                    Text(item.subtitle)
                        .font(.caption).foregroundColor(.white.opacity(0.75))
                }
                .padding(18)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var gradientBackground: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: item.badge == "PRESTIGE PEAK" ? "crown.fill" : "mountain.2.fill")
                .font(.system(size: 70))
                .foregroundColor(.white.opacity(0.06))
        }
    }
}

// === SUGGESTED ROUTE CARD (database mountains) ===
struct SuggestedRouteCard: View {
    let mountain: Mountain
    var onTap: () -> Void

    @State private var isPressed = false
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Mountain photo or gradient placeholder
                if let urlString = mountain.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05))
                        }
                    }
                    .frame(width: 185, height: 90).clipped().cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 185, height: 90)
                        .overlay(
                            Image(systemName: "mountain.2.fill").font(.title2).foregroundColor(.white.opacity(0.3))
                        )
                }

                Text(mountain.name)
                    .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(mountain.elevation)m").font(.caption2).foregroundColor(.gray)
                    Text("·").foregroundColor(.gray)
                    Text(mountain.region).font(.caption2).foregroundColor(.gray).lineLimit(1)
                    Spacer()
                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(mountain.difficulty.color)
                        .cornerRadius(3)
                }

                if mountain.isPrestigePeak {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill").font(.system(size: 8)).foregroundColor(gold)
                        Text("PRESTIGE").font(.system(size: 8, weight: .black)).foregroundColor(gold).tracking(0.5)
                    }
                }
            }
            .padding(10)
            .frame(width: 205)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .cornerRadius(16)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// === LEVEL BADGE ===
struct LevelBadge: View {
    let level: Int
    let progress: Double

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)
                .frame(width: 42, height: 42)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(-90))
            Text("\(level)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(gold)
        }
    }
}

// === DISCOVERY CARD ===
struct DiscoveryCard: View {
    let mountain: Mountain
    var onTap: () -> Void

    @State private var isPressed = false
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(mountain.isPrestigePeak ? gold : .white)
                    Spacer()
                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(mountain.difficulty.color)
                        .cornerRadius(4)
                }

                Text(mountain.name)
                    .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                    .lineLimit(1)

                Text("\(mountain.elevation)m · \(mountain.region)")
                    .font(.caption2).foregroundColor(.gray)
                    .lineLimit(1)

                if mountain.isPrestigePeak {
                    Text("PRESTIGE PEAK")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(gold).tracking(1)
                }
            }
            .padding(14)
            .frame(width: 165, height: 130)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(mountain.isPrestigePeak ? gold.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// === XP DETAIL POPUP ===
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

struct ObjectiveCard: View {
    let icon: String; let title: String; let progress: String; let percent: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(.white).padding(10).background(Color.white.opacity(0.1)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.bold).foregroundColor(.white)
                Text(progress).font(.caption2).fontWeight(.semibold).foregroundColor(.gray)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                    Capsule().fill(Color(red: 0.85, green: 0.65, blue: 0.13)).frame(width: geo.size.width * percent, height: 4)
                }
            }
            .frame(height: 4).padding(.top, 5)
        }
        .padding(16).frame(width: 150, height: 140).background(Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(20)
    }
}

// =========================================
// === All Activities Full-Screen View ===
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
