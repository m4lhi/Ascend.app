import SwiftUI

// =========================================
// === DATEI: ArenaView.swift ===
// === Das Live-Podest (Global/Local/Friends) ===
// =========================================

struct Player: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let xp: Int
    let isCurrentUser: Bool
    let avatarURL: String?
}

struct ArenaView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScope = 0 // 0 = Global, 1 = Local, 2 = Friends
    @State private var showAddFriendAlert = false
    @State private var friendHandleInput = ""
    
    // === NEU: Wählt automatisch die echten Cloud-Daten je nach Tab! ===
    var leaderboard: [Player] {
        let sourceArray: [CloudProfile]
        
        switch selectedScope {
        case 0: sourceArray = appState.globalLeaderboard
        case 1: sourceArray = appState.localLeaderboard
        default: sourceArray = appState.friendsLeaderboard
        }
        
        return sourceArray.map { cloudProfile in
            Player(
                name: cloudProfile.username,
                handle: cloudProfile.handle,
                xp: cloudProfile.xp,
                isCurrentUser: cloudProfile.handle == appState.userHandle,
                avatarURL: cloudProfile.avatar_url
            )
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // === HEADER BEREICH ===
                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("THE ARENA").font(.caption).fontWeight(.bold).foregroundColor(.gray).tracking(2)
                            Text("Leaderboard").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        }
                        Spacer()
                        Button(action: { showAddFriendAlert = true }) {
                            Image(systemName: "person.badge.plus").font(.title)
                                .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                                .padding(10).background(Color.white.opacity(0.05)).clipShape(Circle())
                        }
                    }
                    
                    HStack(spacing: 0) {
                        ScopeButton(title: "Global", isSelected: selectedScope == 0) { selectedScope = 0 }
                        ScopeButton(title: "Local", isSelected: selectedScope == 1) { selectedScope = 1 }
                        ScopeButton(title: "Friends", isSelected: selectedScope == 2) { selectedScope = 2 }
                    }
                    .background(Color.white.opacity(0.05)).cornerRadius(12).padding(.top, 10)
                }
                .padding(.horizontal, 25).padding(.top, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if selectedScope == 2 && leaderboard.count <= 1 {
                            VStack(spacing: 15) {
                                Spacer().frame(height: 50)
                                Image(systemName: "person.3.fill").font(.system(size: 50)).foregroundColor(.gray.opacity(0.5))
                                Text("No friends yet.").font(.headline).foregroundColor(.gray)
                                Text("Tap the + icon top right to add fellow alpinists via their @handle.").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 40)
                            }
                        } else {
                            
                            // === DAS SIEGER-PODEST (TOP 3) ===
                            let topThree = Array(leaderboard.prefix(3))
                            
                            if topThree.count >= 3 {
                                HStack(alignment: .bottom, spacing: 15) {
                                    PodiumCard(rank: 2, player: topThree[1])
                                    PodiumCard(rank: 1, player: topThree[0]).offset(y: -40).zIndex(1)
                                    PodiumCard(rank: 3, player: topThree[2])
                                }
                                .padding(.top, 60).padding(.horizontal, 20).padding(.bottom, 20)
                            } else if topThree.count == 2 {
                                HStack(alignment: .bottom, spacing: 15) {
                                    PodiumCard(rank: 1, player: topThree[0]).zIndex(1)
                                    PodiumCard(rank: 2, player: topThree[1])
                                }
                                .padding(.top, 20).padding(.horizontal, 20).padding(.bottom, 20)
                            } else if topThree.count == 1 {
                                PodiumCard(rank: 1, player: topThree[0]).padding(.top, 20).padding(.horizontal, 100).padding(.bottom, 20)
                            }
                            
                            // === DER REST VOM LEADERBOARD (AB PLATZ 4) ===
                            let remainingPlayers = Array(leaderboard.dropFirst(3))
                            
                            VStack(spacing: 12) {
                                ForEach(Array(remainingPlayers.enumerated()), id: \.element.id) { index, player in
                                    let rank = index + 4
                                    StandardLeaderboardRow(rank: rank, player: player)
                                }
                            }
                            .padding(.horizontal, 20).padding(.bottom, 120)
                        }
                    }
                }
            }
        }
        .onAppear { appState.fetchLeaderboard() }
        .alert("Add Alpinist", isPresented: $showAddFriendAlert) {
            TextField("Enter @handle (e.g. climber)", text: $friendHandleInput).autocapitalization(.none).autocorrectionDisabled()
            Button("Add") { appState.addFriend(handleToSearch: friendHandleInput); friendHandleInput = "" }
            Button("Cancel", role: .cancel) { friendHandleInput = "" }
        } message: { Text("Enter the exact handle of your friend to add them to your live leaderboard.") }
    }
}

// === Hilfs-Views (Unverändert) ===
struct ScopeButton: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline).fontWeight(.bold).foregroundColor(isSelected ? .black : .gray)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(isSelected ? Color(red: 0.85, green: 0.65, blue: 0.13) : Color.clear).cornerRadius(10)
        }
    }
}

struct PodiumCard: View {
    let rank: Int; let player: Player
    var rankColor: Color {
        switch rank { case 1: return Color(red: 0.85, green: 0.65, blue: 0.13); case 2: return Color(red: 0.75, green: 0.75, blue: 0.75); case 3: return Color(red: 0.8, green: 0.5, blue: 0.2); default: return .white }
    }
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                if let urlString = player.avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.gray.opacity(0.2)) }
                    }.frame(width: rank == 1 ? 80 : 60, height: rank == 1 ? 80 : 60).clipShape(Circle()).overlay(Circle().stroke(rankColor, lineWidth: 3))
                } else {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: rank == 1 ? 80 : 60, height: rank == 1 ? 80 : 60)
                        .overlay(Text(String(player.name.prefix(1))).fontWeight(.bold).foregroundColor(rankColor)).overlay(Circle().stroke(rankColor, lineWidth: 3))
                }
                Text("\(rank)").font(.caption).fontWeight(.black).foregroundColor(.black).frame(width: 24, height: 24).background(rankColor).clipShape(Circle()).offset(y: 10)
            }.padding(.bottom, 8)
            Text(player.name).font(.subheadline).fontWeight(player.isCurrentUser ? .bold : .semibold).foregroundColor(player.isCurrentUser ? .white : .white.opacity(0.9)).lineLimit(1)
            Text("@\(player.handle)").font(.caption2).foregroundColor(.gray).lineLimit(1)
            Text("\(player.xp) XP").font(.headline).fontWeight(.black).foregroundColor(rankColor)
        }.frame(maxWidth: .infinity).padding(.vertical, 20).padding(.horizontal, 5).background(RoundedRectangle(cornerRadius: 20).fill(player.isCurrentUser ? Color.white.opacity(0.1) : Color(red: 0.12, green: 0.12, blue: 0.15))).overlay(RoundedRectangle(cornerRadius: 20).stroke(rankColor.opacity(0.8), lineWidth: rank == 1 ? 2 : 1)).shadow(color: rankColor.opacity(0.15), radius: 10, y: 5)
    }
}

struct StandardLeaderboardRow: View {
    let rank: Int; let player: Player
    var body: some View {
        HStack(spacing: 15) {
            Text("#\(rank)").font(.headline).fontWeight(.bold).foregroundColor(.gray).frame(width: 35, alignment: .leading)
            if let urlString = player.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.gray.opacity(0.2)) }
                }.frame(width: 40, height: 40).clipShape(Circle())
            } else {
                Circle().fill(Color.white.opacity(0.1)).frame(width: 40, height: 40).overlay(Text(String(player.name.prefix(1))).fontWeight(.bold).foregroundColor(.gray))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.subheadline).fontWeight(player.isCurrentUser ? .bold : .regular).foregroundColor(player.isCurrentUser ? .white : .white.opacity(0.8))
                Text("@\(player.handle)").font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            Text("\(player.xp) XP").font(.subheadline).fontWeight(.bold).foregroundColor(player.isCurrentUser ? Color(red: 0.85, green: 0.65, blue: 0.13) : .white.opacity(0.8))
        }.padding(15).background(player.isCurrentUser ? Color.white.opacity(0.08) : Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(player.isCurrentUser ? Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.5) : Color.clear, lineWidth: 1))
    }
}
