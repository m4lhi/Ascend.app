import SwiftUI

// =========================================
// === DATEI: BasecampView.swift ===
// === Das ULTIMATIVE Basecamp (Alles vereint) ===
// =========================================

struct BasecampView: View {
    @EnvironmentObject var appState: AppState
    @State private var showXPDetails = false
    
    // Berechnet die echten Höhenmeter für das "Iron Legs" Objective
    // WICHTIG: Nutzt jetzt die neue Variable 'elevationGainMeters'
    var totalElevation: Int {
        appState.recentTours.filter { $0.isCurrentUser }.reduce(0) { $0 + $1.elevationGainMeters }
    }
    
    // Zählt, wie viele Touren DU selbst gemacht hast
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
                VStack(alignment: .leading, spacing: 35) {
                    
                    // === HEADER ===
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BASECAMP").font(.caption).fontWeight(.bold).foregroundColor(.gray).tracking(1.5)
                            Text(appState.userName).font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                            if let firstSport = appState.selectedSports.first {
                                Text(firstSport).font(.caption).foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        
                        // Dein eigenes Cloud-Profilbild im Header
                        if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Circle().fill(Color.gray.opacity(0.2)) // Lade-Platzhalter
                                }
                            }
                            .frame(width: 50, height: 50).clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        } else {
                            Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1).frame(width: 50, height: 50)
                                .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 20)
                    
                    // === LEVEL KARTE ===
                    Button(action: { showXPDetails = true }) {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Alpinist Rank").font(.title3).fontWeight(.bold).foregroundColor(.white)
                                    Text("Level \(appState.currentLevel)").font(.subheadline).foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                                }
                                Spacer()
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("\(appState.currentLevelProgressXP)").font(.title2).fontWeight(.bold).foregroundColor(.white)
                                    Text("XP").font(.caption).foregroundColor(.gray)
                                }
                            }
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                                        Capsule().fill(Color(red: 0.85, green: 0.65, blue: 0.13))
                                            .frame(width: geometry.size.width * CGFloat(appState.currentLevelProgressXP) / CGFloat(appState.xpNeededForNextLevel), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                Text("\(appState.xpNeededForNextLevel - appState.currentLevelProgressXP) XP TO PEAK").font(.caption2).fontWeight(.bold).foregroundColor(.gray)
                            }
                        }
                        .padding(20).background(Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    
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
                    
                    // === RECENT ACTIVITY (FEED) ===
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
                            // === HIER SIND DIE NEUEN KARTEN! ===
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
        .onAppear { appState.fetchFeed() }
        .sheet(isPresented: $showXPDetails) {
            XPDetailView().presentationDetents([.medium, .large]).preferredColorScheme(.dark)
        }
    }
}

// === Hilfs-Views (XP Popup & Objective Cards) ===
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
                    // Update auf elevationGainMeters
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
