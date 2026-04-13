import SwiftUI

// =========================================
// === DATEI: ArenaView.swift ===
// === Leaderboard — Emotionally Intelligent ===
// =========================================

struct Player: Identifiable {
    let id: UUID
    let name: String
    let handle: String
    let xp: Int
    let isCurrentUser: Bool
    let avatarURL: String?
}

// =========================================
// MARK: - Main Arena View
// =========================================

struct ArenaView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScope = 0
    @State private var showAddFriendAlert = false
    @State private var friendHandleInput = ""
    @State private var animateIn = false
    @State private var podiumRevealed = false
    @State private var rowsRevealed = false
    @State private var headerGlow = false

    private let gold = DesignSystem.Colors.accent // Light Blue Accent
    private let bg = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.98, blue: 1.00),
            Color(red: 0.90, green: 0.94, blue: 1.00)
        ],
        startPoint: .top, endPoint: .bottom
    )
    private let cardBg = Color.white

    var leaderboard: [Player] {
        let sourceArray: [CloudProfile]
        switch selectedScope {
        case 0: sourceArray = appState.globalLeaderboard
        case 1: sourceArray = appState.localLeaderboard
        default: sourceArray = appState.friendsLeaderboard
        }
        return sourceArray.map { p in
            Player(id: p.id, name: p.username, handle: p.handle, xp: p.xp,
                   isCurrentUser: p.handle == appState.userHandle,
                   avatarURL: p.avatar_url)
        }
    }

    // Motivational message based on ranking
    private var motivationalMessage: (String, String) {
        guard let myIndex = leaderboard.firstIndex(where: { $0.isCurrentUser }) else {
            return ("Welcome to the Arena", "Start climbing to earn your rank")
        }
        let rank = myIndex + 1
        switch rank {
        case 1:
            return ("You're at the summit", "The view from the top is earned, not given")
        case 2...3:
            return ("Almost there", "The summit is within reach — keep pushing")
        case 4...10:
            return ("Gaining altitude", "You're climbing strong — \(rank - 1) alpinists ahead")
        default:
            return ("Every ascent starts here", "One step at a time — you've got this")
        }
    }

    private var scopeSubtitle: String {
        switch selectedScope {
        case 0: return "\(leaderboard.count) alpinists worldwide"
        case 1: return leaderboard.isEmpty ? "Set your region in settings" : "\(leaderboard.count) in your region"
        default: return "\(leaderboard.count) friend\(leaderboard.count == 1 ? "" : "s")"
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            // Logo glow
            Circle()
                .fill(DesignSystem.Colors.accent.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: -120, y: -260)
                .allowsHitTesting(false)

            // Ambient color blobs (GPU-optimized)
            Circle()
                .fill(RadialGradient(colors: [gold.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: 140))
                .frame(width: 280, height: 280)
                .offset(x: 100, y: -150)
            Circle()
                .fill(RadialGradient(colors: [Color.cyan.opacity(0.07), Color.clear], center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .offset(x: -120, y: 200)

            // Subtle mountain silhouette background
            VStack {
                MountainSilhouette()
                    .fill(
                        LinearGradient(
                            colors: [gold.opacity(0.03), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 220)
                    .offset(y: -20)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ============================================
                // MARK: - HEADER
                // ============================================
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            // Motivational greeting
                            Text(motivationalMessage.0.uppercased())
                                .font(.app(size: 11, weight: .black))
                                .foregroundColor(gold.opacity(0.7))
                                .tracking(2.5)

                            Text("The Arena")
                                .font(.app(size: 32, weight: .black))
                                .foregroundStyle(.black)

                            Text(motivationalMessage.1)
                                .font(.app(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 12)

                        Spacer()

                        Button(action: { showAddFriendAlert = true }) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .light)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle().stroke(gold.opacity(0.2), lineWidth: 1)
                                    )

                                Image(systemName: "person.badge.plus")
                                    .font(.app(size: 17, weight: .semibold))
                                    .foregroundColor(gold)
                            }
                        }
                        .opacity(animateIn ? 1 : 0)
                        .scaleEffect(animateIn ? 1 : 0.8)
                    }

                    // Animated Scope Selector
                    AnimatedScopeSelector(
                        selectedScope: $selectedScope,
                        subtitle: scopeSubtitle,
                        gold: gold
                    )
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // ============================================
                // MARK: - CONTENT
                // ============================================
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if selectedScope == 2 && leaderboard.count <= 1 {
                            EmptyFriendsView(gold: gold, onAdd: { showAddFriendAlert = true })
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            // === PODIUM (TOP 3) ===
                            let topThree = Array(leaderboard.prefix(3))

                            if !topThree.isEmpty {
                                PremiumPodiumView(
                                    players: topThree,
                                    isRevealed: podiumRevealed
                                )
                                .padding(.top, 16)
                                .padding(.bottom, 28)
                            }

                            // === REST OF LEADERBOARD ===
                            let remaining = Array(leaderboard.dropFirst(3))
                            if !remaining.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(remaining.enumerated()), id: \.element.id) { index, player in
                                        PremiumLeaderboardRow(
                                            rank: index + 4,
                                            player: player,
                                            gold: gold,
                                            isRevealed: rowsRevealed,
                                            delay: Double(index) * 0.05,
                                            isFirst: index == 0,
                                            isLast: index == remaining.count - 1
                                        )

                                        if index < remaining.count - 1 {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.04))
                                                .frame(height: 0.5)
                                                .padding(.leading, 72)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .environment(\.colorScheme, .light)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.06), radius: 15, y: 6)
                                .padding(.horizontal, 20)
                            }

                            // === MOTIVATIONAL CATCH-UP BANNER ===
                            if let myIndex = leaderboard.firstIndex(where: { $0.isCurrentUser }), myIndex >= 3 {
                                MotivationalBanner(
                                    rank: myIndex + 1,
                                    xp: leaderboard[myIndex].xp,
                                    nextPlayer: myIndex > 0 ? leaderboard[myIndex - 1] : nil,
                                    gold: gold
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .opacity(rowsRevealed ? 1 : 0)
                                .offset(y: rowsRevealed ? 0 : 16)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: rowsRevealed)
                            }

                            Spacer().frame(height: 130)
                        }
                    }
                }
            }
        }
        .onAppear {
            appState.fetchLeaderboard()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                animateIn = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.78).delay(0.35)) {
                podiumRevealed = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.55)) {
                rowsRevealed = true
            }
        }
        .onChange(of: selectedScope) { _, _ in
            // Re-trigger animations on scope change
            podiumRevealed = false
            rowsRevealed = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                podiumRevealed = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.25)) {
                rowsRevealed = true
            }
        }
        .alert("Add Alpinist", isPresented: $showAddFriendAlert) {
            TextField("Enter @handle", text: $friendHandleInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Add") {
                appState.addFriend(handleToSearch: friendHandleInput)
                friendHandleInput = ""
            }
            Button("Cancel", role: .cancel) { friendHandleInput = "" }
        } message: {
            Text("Enter the exact handle of your friend to add them to your live leaderboard.")
        }
    }
}

// =========================================
// MARK: - Mountain Silhouette Shape
// =========================================

struct MountainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.65))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.3))
        path.addLine(to: CGPoint(x: w, y: h * 0.6))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

// =========================================
// MARK: - Animated Scope Selector
// =========================================

struct AnimatedScopeSelector: View {
    @Binding var selectedScope: Int
    let subtitle: String
    let gold: Color

    @Namespace private var scopeAnimation

    private let scopes: [(String, String)] = [
        ("Globe", "globe"),
        ("Local", "location.fill"),
        ("Friends", "person.2.fill")
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            selectedScope = index
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: scopes[index].1)
                                .font(.app(size: 10, weight: .bold))
                            Text(scopes[index].0)
                                .font(.app(size: 13, weight: .bold))
                        }
                        .foregroundColor(selectedScope == index ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            ZStack {
                                if selectedScope == index {
                                    Capsule()
                                        .fill(gold)
                                        .matchedGeometryEffect(id: "scope_bg", in: scopeAnimation)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )

            // Contextual subtitle
            Text(subtitle)
                .font(.app(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))
                .animation(.easeInOut(duration: 0.3), value: selectedScope)
        }
    }
}

// =========================================
// MARK: - Premium Podium View
// =========================================

struct PremiumPodiumView: View {
    let players: [Player]
    var isRevealed: Bool = true
    
    @EnvironmentObject var appState: AppState

    private let gold = DesignSystem.Colors.accent
    private let silver = Color(red: 0.6, green: 0.65, blue: 0.75)
    private let bronze = Color(red: 0.82, green: 0.52, blue: 0.22)

    private func rankColor(_ rank: Int) -> Color {
        switch rank { case 1: return gold; case 2: return silver; case 3: return bronze; default: return .gray }
    }

    @State private var selectedProfile: Player?

    var body: some View {
        Group {
            if players.count >= 3 {
                HStack(alignment: .bottom, spacing: 6) {
                    // 2nd place — appears first in choreography
                    podiumColumn(player: players[1], rank: 2, avatarSize: 60, pillarHeight: 72)
                        .opacity(isRevealed ? 1 : 0)
                        .offset(y: isRevealed ? 0 : 30)
                        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.0), value: isRevealed)

                    // 1st place — the star, appears second
                    podiumColumn(player: players[0], rank: 1, avatarSize: 78, pillarHeight: 105)
                        .opacity(isRevealed ? 1 : 0)
                        .offset(y: isRevealed ? 0 : 40)
                        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.12), value: isRevealed)

                    // 3rd place — appears third
                    podiumColumn(player: players[2], rank: 3, avatarSize: 54, pillarHeight: 56)
                        .opacity(isRevealed ? 1 : 0)
                        .offset(y: isRevealed ? 0 : 25)
                        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.06), value: isRevealed)
                }
                .padding(.horizontal, 14)
            } else if players.count == 2 {
                HStack(alignment: .bottom, spacing: 12) {
                    podiumColumn(player: players[0], rank: 1, avatarSize: 78, pillarHeight: 105)
                    podiumColumn(player: players[1], rank: 2, avatarSize: 60, pillarHeight: 72)
                }
                .padding(.horizontal, 40)
                .opacity(isRevealed ? 1 : 0)
                .offset(y: isRevealed ? 0 : 30)
            } else if players.count == 1 {
                podiumColumn(player: players[0], rank: 1, avatarSize: 78, pillarHeight: 105)
                    .padding(.horizontal, 80)
                    .opacity(isRevealed ? 1 : 0)
                    .offset(y: isRevealed ? 0 : 30)
            }
        }
        .sheet(item: $selectedProfile) { p in
            PublicProfileView(
                userId: p.id,
                userName: p.name,
                userHandle: p.handle,
                avatarURL: p.avatarURL,
                xp: p.xp
            )
            .presentationDetents([.fraction(0.85), .large])
            .preferredColorScheme(.light)
            .environmentObject(appState)
        }
    }

    @ViewBuilder
    private func podiumColumn(player: Player, rank: Int, avatarSize: CGFloat, pillarHeight: CGFloat) -> some View {
        let color = rankColor(rank)

        Button(action: {
            selectedProfile = player
        }) {
            VStack(spacing: 0) {
            // Crown for #1 with glow
            if rank == 1 {
                ZStack {
                    Image(systemName: "crown.fill")
                        .font(.app(size: 24))
                        .foregroundColor(gold.opacity(0.3))
                        .blur(radius: 8)

                    Image(systemName: "crown.fill")
                        .font(.app(size: 22))
                        .foregroundColor(gold)
                }
                .padding(.bottom, 6)
            }

            // Avatar with progress ring
            ZStack(alignment: .center) {
                // Glow behind avatar for #1
                if rank == 1 {
                    Circle()
                        .fill(gold.opacity(0.15))
                        .frame(width: avatarSize + 20, height: avatarSize + 20)
                        .blur(radius: 12)
                }

                // Avatar ring
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: rank == 1 ? 3.5 : 2.5)
                    .frame(width: avatarSize + 6, height: avatarSize + 6)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: rank == 1 ? 3.5 : 2.5, lineCap: .round)
                    )
                    .frame(width: avatarSize + 6, height: avatarSize + 6)
                    .rotationEffect(.degrees(-90))

                // Avatar image
                if let urlString = player.avatarURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.06))
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Text(String(player.name.prefix(1)).uppercased())
                                .font(.system(size: avatarSize * 0.35, weight: .bold, design: .rounded))
                                .foregroundColor(color)
                        )
                }

                // Rank badge
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .shadow(color: color.opacity(0.5), radius: 6)

                    Text("\(rank)")
                        .font(.app(size: 12, weight: .black))
                        .foregroundColor(.white)
                }
                .offset(y: (avatarSize / 2) + 2) // Badge exakt an den unteren Rand setzen
            }
            .padding(.bottom, 18)

            // Name with shimmer for #1
            if rank == 1 {
                Text(player.name)
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .modifier(ShimmerModifier(color: gold))
            } else {
                Text(player.name)
                    .font(.system(size: rank == 2 ? 14 : 13, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }

            Text("@\(player.handle)")
                .font(.app(size: 10))
                .foregroundColor(.gray)
                .lineLimit(1)
                .padding(.bottom, 8)

            // XP with animated feel
            Text(formatXP(player.xp))
                .font(.system(size: rank == 1 ? 24 : 18, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text("XP")
                .font(.app(size: 9, weight: .bold))
                .foregroundColor(color.opacity(0.5))
                .tracking(1)
                .padding(.bottom, 10)

            // Glassmorphic Pillar
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .frame(height: pillarHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: color.opacity(rank == 1 ? 0.2 : 0.1), radius: rank == 1 ? 12 : 6, y: 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func formatXP(_ xp: Int) -> String {
        if xp >= 10000 {
            return String(format: "%.1fk", Double(xp) / 1000.0)
        }
        return "\(xp)"
    }
}

// =========================================
// MARK: - Shimmer Modifier
// =========================================

struct ShimmerModifier: ViewModifier {
    let color: Color
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            color.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.3 + phase * (geo.size.width * 1.6))
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// =========================================
// MARK: - Premium Leaderboard Row
// =========================================

struct PremiumLeaderboardRow: View {
    let rank: Int
    let player: Player
    let gold: Color
    var isRevealed: Bool = true
    var delay: Double = 0
    var isFirst: Bool = false
    var isLast: Bool = false

    @State private var showPublicProfile = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(action: {
            showPublicProfile = true
        }) {
            HStack(spacing: 14) {
                // Rank number
                Text("\(rank)")
                    .font(.app(size: 15, weight: .bold))
                    .foregroundColor(player.isCurrentUser ? gold : .black.opacity(0.4))
                    .frame(width: 30, alignment: .center)

            // Avatar with mini progress ring
            ZStack {
                if let urlString = player.avatarURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.06))
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Text(String(player.name.prefix(1)).uppercased())
                                .font(.app(size: 16, weight: .bold))
                                .foregroundColor(player.isCurrentUser ? gold : .gray)
                        )
                }

                // Subtle progress ring
                Circle()
                    .trim(from: 0, to: min(Double(player.xp % 1000) / 1000.0, 1.0))
                    .stroke(
                        player.isCurrentUser ? gold.opacity(0.5) : Color.black.opacity(0.1),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
            }

            // Name, handle & level badge
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.system(size: 15, weight: player.isCurrentUser ? .bold : .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if player.isCurrentUser {
                        Text("YOU")
                            .font(.app(size: 8, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(gold)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text("@\(player.handle)")
                        .font(.app(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    // Level indicator
                    let level = max(1, (player.xp / 1000) + 1)
                    Text("Lv.\(level)")
                        .font(.app(size: 9, weight: .bold))
                        .foregroundColor(RankTitle.forLevel(level).color.opacity(0.7))
                }
            }

            Spacer()

            // XP
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.xp)")
                    .font(.app(size: 17, weight: .bold))
                    .foregroundColor(player.isCurrentUser ? gold : .black)
                Text("XP")
                    .font(.app(size: 9, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
                    .tracking(0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            player.isCurrentUser
                ? AnyShapeStyle(gold.opacity(0.06))
                : AnyShapeStyle(Color.clear)
        )
        .overlay(alignment: .leading) {
            // Gold left accent for current user — aligned to leading edge
            if player.isCurrentUser {
                UnevenRoundedRectangle(
                    topLeadingRadius: isFirst ? 22 : 0,
                    bottomLeadingRadius: isLast ? 22 : 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(gold)
                .frame(width: 3.5)
            }
        }
        }
        .buttonStyle(.plain)
        .opacity(isRevealed ? 1 : 0)
        .offset(x: isRevealed ? 0 : 20)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8).delay(delay),
            value: isRevealed
        )
        .sheet(isPresented: $showPublicProfile) {
            PublicProfileView(
                userId: player.id,
                userName: player.name,
                userHandle: player.handle,
                avatarURL: player.avatarURL,
                xp: player.xp
            )
            .presentationDetents([.fraction(0.85), .large])
            .preferredColorScheme(.light)
            .environmentObject(appState)
        }
    }
}

// =========================================
// MARK: - Motivational Banner
// =========================================

struct MotivationalBanner: View {
    let rank: Int
    let xp: Int
    let nextPlayer: Player?
    let gold: Color

    private var xpGap: Int {
        guard let next = nextPlayer else { return 0 }
        return next.xp - xp
    }

    private var progress: CGFloat {
        guard let next = nextPlayer, next.xp > 0 else { return 0.5 }
        // How close are we? If gap is small relative to our XP, we're close
        let totalRange = Double(next.xp)
        return min(CGFloat(Double(xp) / totalRange), 0.95)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(gold.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "flame.fill")
                        .font(.app(size: 15, weight: .bold))
                        .foregroundColor(gold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("You're ranked #\(rank)")
                        .font(.app(size: 14, weight: .bold))
                        .foregroundColor(.black)

                    if let next = nextPlayer, xpGap > 0 {
                        Text("\(xpGap) XP to overtake @\(next.handle)")
                            .font(.app(size: 12, weight: .medium))
                            .foregroundColor(gold.opacity(0.8))
                    }
                }

                Spacer()

                Text("\(xp) XP")
                    .font(.app(size: 15, weight: .black))
                    .foregroundColor(gold)
            }

            // Progress bar toward next rank
            if nextPlayer != nil && xpGap > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 5)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [gold.opacity(0.6), gold],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * progress), height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(gold.opacity(0.15), lineWidth: 1)
        )
    }
}

// =========================================
// MARK: - Empty Friends View
// =========================================

struct EmptyFriendsView: View {
    let gold: Color
    let onAdd: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 50)

            // Animated mountain + people illustration
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(gold.opacity(0.04))
                    .frame(width: 150, height: 150)

                Circle()
                    .fill(gold.opacity(0.06))
                    .frame(width: 110, height: 110)

                // Mountain icon
                ZStack {
                    Image(systemName: "mountain.2.fill")
                        .font(.app(size: 44))
                        .foregroundColor(gold.opacity(0.12))
                        .offset(y: 8)

                    Image(systemName: "person.3.fill")
                        .font(.app(size: 32))
                        .foregroundColor(gold.opacity(0.45))
                        .offset(y: floatOffset)
                }
            }

            VStack(spacing: 10) {
                Text("The summit is better shared")
                    .font(.app(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Invite fellow alpinists to compete,\ncheer each other on, and climb together.")
                    .font(.app(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.app(size: 14, weight: .bold))
                    Text("Add Friend")
                        .font(.app(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(gold)
                .clipShape(Capsule())
                .shadow(color: gold.opacity(0.3), radius: 12, y: 4)
                .scaleEffect(pulseScale)
            }
            .padding(.top, 4)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                floatOffset = -6
            }
        }
    }
}
