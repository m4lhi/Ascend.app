import SwiftUI

// =========================================
// === DATEI: BasecampView.swift ===
// === Social Dashboard mit Discovery ===
// =========================================

struct BasecampView: View {
    @EnvironmentObject var appState: AppState
    @State private var showXPDetails = false
    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil

    var totalElevation: Int {
        appState.recentTours.filter { $0.isCurrentUser }.reduce(0) { $0 + $1.elevationGainMeters }
    }

    var totalOwnTours: Int {
        appState.recentTours.filter { $0.isCurrentUser }.count
    }

    var ironLegsProgress: CGFloat {
        min(CGFloat(totalElevation) / 5000.0, 1.0)
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

                    // === WEEKLY OBJECTIVES ===
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Weekly Objectives").font(.title3).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                Spacer().frame(width: 5)
                                ObjectiveCard(icon: "figure.walk", title: "Iron Legs", progress: "\(totalElevation)M / 5,000M", percent: ironLegsProgress)
                                ObjectiveCard(icon: "mountain.2.fill", title: "Explorer", progress: "\(totalOwnTours)/3 PEAKS", percent: min(CGFloat(totalOwnTours) / 3.0, 1.0))
                                ObjectiveCard(icon: "lock.fill", title: "Altitude", progress: "LOCKED", percent: 0.0)
                                Spacer().frame(width: 5)
                            }
                        }
                    }

                    // === SOCIAL FEED ===
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recent Activity").font(.title3).fontWeight(.bold).foregroundColor(.white)

                        if appState.recentTours.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.climbing").font(.system(size: 40)).foregroundColor(.gray.opacity(0.5))
                                Text("Your journey begins here.").font(.headline).foregroundColor(.white)
                                Text("Track your first mission to see your activity.").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(30).background(Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(20)
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(appState.recentTours) { tour in
                                    ActivityCardView(tour: tour)
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
        .fullScreenCover(isPresented: $showTracker) {
            LiveRecordView(targetMountain: mountainToTrack)
        }
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// === XP DETAIL POPUP ===
struct XPDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
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
                    Text("Top 15% in Bavaria").font(.subheadline).foregroundColor(.green)
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
