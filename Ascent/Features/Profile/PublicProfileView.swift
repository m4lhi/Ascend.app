import SwiftUI
import Supabase

struct PublicProfileView: View {
    let userId: UUID?
    let initialUserName: String
    let initialUserHandle: String
    let initialAvatarURL: String?
    
    @State private var userName: String
    @State private var userHandle: String
    @State private var avatarURL: String?
    @State private var region: String?
    @State private var xp: Int = 0 // Will fetch live
    
    init(userId: UUID?, userName: String, userHandle: String, avatarURL: String?, xp: Int = 0) {
        self.userId = userId
        self.initialUserName = userName
        self.initialUserHandle = userHandle
        self.initialAvatarURL = avatarURL
        
        self._userName = State(initialValue: userName)
        self._userHandle = State(initialValue: userHandle)
        self._avatarURL = State(initialValue: avatarURL)
        self._xp = State(initialValue: xp) // Set initial if provided
    }
    
    // Simulate equipment based on user string to keep it consistent
    @State private var equipment: Equipment = Equipment()
    @State private var isLoading = false
    @State private var isSelf = true
    @State private var isFriend = true
    @State private var addingFriend = false
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var leaderboardVM: LeaderboardViewModel

    private let accent = DesignSystem.Colors.accent
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var level: Int {
        return max(1, (xp / 1000) + 1)
    }
    
    var rank: RankTitle {
        return RankTitle.forLevel(level)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Header
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                // Avatar Circle
                                ZStack {
                                    Circle()
                                        .fill(rank.color.opacity(0.15))
                                        .frame(width: 110, height: 110)
                                    
                                    Circle()
                                        .stroke(rank.color, lineWidth: 3)
                                        .frame(width: 100, height: 100)
                                    
                                    if let urlString = avatarURL, let url = URL(string: urlString) {
                                        CachedAsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Circle().fill(Color.gray.opacity(0.2))
                                        }
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(LinearGradient(colors: [rank.color.opacity(0.6), rank.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 90, height: 90)
                                            .overlay(
                                                Text(String(userName.prefix(1)).uppercased())
                                                    .font(.app(size: 36, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                                .padding(.top, 20)
                                
                                // Level badge as Shield
                                if !isLoading {
                                    ZStack {
                                        Image(systemName: "hexagon.fill")
                                            .font(.app(size: 38))
                                            .foregroundColor(rank.color)
                                        
                                        Image(systemName: "hexagon")
                                            .font(.app(size: 38))
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        Text("\(level)")
                                            .font(.app(size: 16, weight: .black))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 10, y: 5)
                                }
                            }
                            
                            VStack(spacing: 4) {
                                Text(userName)
                                    .font(.app(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 6) {
                                    Text("@\(userHandle)")
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    Text("•")
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text(rank.rawValue.uppercased())
                                        .font(.app(size: 11, weight: .black))
                                        .foregroundColor(rank.color)
                                        .tracking(1)
                                }
                                .font(.app(size: 15))
                                
                                // Bio / Region
                                if let r = region, !r.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .foregroundColor(accent)
                                        Text(r)
                                    }
                                    .font(.app(size: 14, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                    .padding(.top, 4)
                                } else {
                                    // Default tagline
                                    Text("Exploring the peaks")
                                        .font(.app(size: 14, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                        .padding(.top, 4)
                                }
                            }
                            
                            if isLoading {
                                ProgressView()
                                    .padding(.top, 8)
                            } else {
                                HStack(spacing: 16) {
                                    StatPill(title: "XP", value: "\(xp)", icon: "bolt.fill", color: accent)
                                    StatPill(title: "Reputation", value: "Level \(level)", icon: rank.icon, color: rank.color)
                                }
                                .padding(.top, 8)
                            }
                        }
                        
                        // Add Friend Button
                        if !isLoading && !isSelf && !isFriend {
                            Button(action: {
                                addingFriend = true
                                Task {
                                    leaderboardVM.addFriend(handleToSearch: userHandle)
                                    await MainActor.run {
                                        // Assume it works locally for UI feedback
                                        isFriend = true
                                        addingFriend = false
                                    }
                                }
                            }) {
                                HStack {
                                    if addingFriend {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                        Text("Add Crew")
                                    }
                                }
                                .font(.app(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(accent)
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        }
                        // Fake Top Badges Showcase
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "trophy.fill").foregroundColor(gold)
                                Text("Top Achievements").font(.app(size: 14, weight: .bold)).foregroundColor(DesignSystem.Colors.secondaryText).textCase(.uppercase)
                            }
                            .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Deterministische Auswahl von 3 Badges basierend auf Namen
                                    let baseIndex = userName.count
                                    let titles = ["First Summit", "Elevation Hunter", "Social Climber", "Sky Walker", "Century Club"]
                                    let icons = ["mountain.2.fill", "arrow.up.right.circle.fill", "person.2.fill", "cloud.fill", "crown.fill"]
                                    let colors: [Color] = [.green, .orange, .cyan, .blue, gold]
                                    
                                    ForEach(0..<3, id: \.self) { i in
                                        let idx = (baseIndex + i) % titles.count
                                        PublicBadgeItem(title: titles[idx], icon: icons[idx], color: colors[idx])
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.top, 10)
                        
                        // Equipment Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "backpack.fill").foregroundColor(DesignSystem.Colors.secondaryText)
                                Text("Equipment Locker").font(.app(size: 14, weight: .bold)).foregroundColor(DesignSystem.Colors.secondaryText).textCase(.uppercase)
                            }
                            .padding(.horizontal, 24)
                            
                            // We pass binding, but we don't handle clicks
                            EquipmentLockerView(equipment: equipment)
                                .disabled(true) // Read only
                        }
                        .padding(.top, 10)
                        
                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.app(size: 24))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .onAppear {
                seedEquipment()
                Task {
                    await fetchUserProfileAsync()
                }
            }
        }
    }
    
    private func fetchUserProfileAsync() async {
        guard let id = userId else {
            await MainActor.run { isLoading = false }
            return
        }
        
        // Track ownership & friendship
        let myId = try? await supabase.auth.session.user.id
        let selfStatus = (myId == id)
        
        var friendStatus = leaderboardVM.friendsLeaderboard.contains { $0.id == id }
        if !friendStatus, let myId = myId {
            do {
                let existingFriendships: [FriendshipRule] = try await supabase.from("friendships").select("friend_id").eq("user_id", value: myId).eq("friend_id", value: id).execute().value
                friendStatus = !existingFriendships.isEmpty
            } catch {
                print("Failed to fetch friendship status: \(error)")
            }
        }
        
        await MainActor.run {
            self.isSelf = selfStatus
            self.isFriend = friendStatus
        }
        
        do {
            let profiles: [CloudProfile] = try await supabase.from("profiles").select().eq("id", value: id).execute().value
            if let profile = profiles.first {
                await MainActor.run {
                    self.userName = profile.username
                    self.userHandle = profile.handle
                    self.avatarURL = profile.avatar_url
                    self.region = profile.region
                    self.xp = profile.xp
                }
            } else {
                print("Profile not found in DB - using dummy stats")
            }
        } catch {
            print("Failed to fetch public profile: \(error)")
        }
    }
    
    private func seedEquipment() {
        // Pseudorandom gear based on user name length or characters
        let hIdx = userName.count % EquipmentCatalog.heads.count
        let jIdx = (userName.count + 1) % EquipmentCatalog.jackets.count
        let bIdx = (userName.count + 2) % EquipmentCatalog.backpacks.count
        let pIdx = (userName.count + 3) % EquipmentCatalog.pantsItems.count
        let sIdx = (userName.count + 4) % EquipmentCatalog.bootsItems.count
        let eIdx = (userName.count + 5) % EquipmentCatalog.extrasItems.count
        
        let h = EquipmentCatalog.heads[hIdx]; equipment.head = "\(h.brand) \(h.name)"
        let j = EquipmentCatalog.jackets[jIdx]; equipment.jacket = "\(j.brand) \(j.name)"
        let b = EquipmentCatalog.backpacks[bIdx]; equipment.backpack = "\(b.brand) \(b.name)"
        let p = EquipmentCatalog.pantsItems[pIdx]; equipment.pants = "\(p.brand) \(p.name)"
        let s = EquipmentCatalog.bootsItems[sIdx]; equipment.boots = "\(s.brand) \(s.name)"
        let e = EquipmentCatalog.extrasItems[eIdx]; equipment.extras = "\(e.brand) \(e.name)"
    }
}

private struct PublicBadgeItem: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 60, height: 60)
                Image(systemName: icon).font(.app(size: 24)).foregroundColor(color)
            }
            Text(title)
                .font(.app(size: 11, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 90)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.app(size: 14))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.app(size: 16, weight: .bold))
                Text(title)
                    .font(.app(size: 10))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }
}
