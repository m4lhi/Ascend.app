import SwiftUI

// =========================================
// === DATEI: AscendProgressView.swift ===
// === Das Ascend Rank System ===
// =========================================

struct AscendProgressView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(DesignSystem.Typography.appFont(style: .title3))
                            .foregroundColor(.primary)
                            .padding()
                    }
                    Spacer()
                    Text("Ascend Rank")
                        .font(DesignSystem.Typography.appFont(style: .headline))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    // Balance space
                    Button(action: { }) {
                        Image(systemName: "chevron.down").foregroundColor(.clear).padding()
                    }
                }
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        if let profile = appState.ascendProfile {
                            AscendCard(profile: profile)
                                .padding(.top, 10)
                                .padding(.horizontal, 20)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Your progress")
                                    .font(DesignSystem.Typography.appFont(style: .title2))
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Unlock perks, rewards, and recognition as you level up your Ascend Rank.")
                                    .font(DesignSystem.Typography.appFont(style: .subheadline))
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 25)
                            .padding(.top, 15)
                            
                            // RANK ROADMAP
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Tier Progression")
                                    .font(DesignSystem.Typography.appFont(style: .title2))
                                    .fontWeight(.black)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 25)
                                
                                RankRoadmapView(currentLevel: profile.ascend_level)
                                    .padding(.horizontal, 25)
                            }
                            .padding(.top, 10)
                            
                        } else {
                            // Loading state or nil state
                            ProgressView().tint(.gray)
                                .padding(.top, 100)
                            Text("Loading Rank Data...").foregroundColor(.gray).padding()
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

// =========================================
// === ASCEND CARD ===
// =========================================

struct AscendCard: View {
    let profile: AscendProfile
    
    @State private var animateGems = false
    
    // Tier Colors based on user prompt requirements
    var tierColor: Color {
        switch profile.ascend_tier.lowercased() {
        case "bronze": return Color(red: 0.8, green: 0.45, blue: 0.15) // brown/orange
        case "silver": return Color(red: 0.7, green: 0.75, blue: 0.8) // grey/blue
        case "gold": return Color(red: 0.95, green: 0.8, blue: 0.2) // yellow
        case "platinum": return Color(red: 0.7, green: 0.5, blue: 0.95) // light purple
        case "obsidian": return Color(red: 0.2, green: 0.1, blue: 0.3) // dark purple
        default: return Color(red: 0.8, green: 0.45, blue: 0.15)
        }
    }
    
    var textColor: Color {
        profile.ascend_tier.lowercased() == "obsidian" ? .black : tierColor
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // Top Half: Gems with Gradient Background
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        Color(white: 0.95),
                        tierColor.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Obsidian Glow specific
                if profile.ascend_tier.lowercased() == "obsidian" {
                    Circle()
                        .fill(RadialGradient(colors: [Color.purple.opacity(0.3), Color.clear], center: .center, startRadius: 0, endRadius: 100))
                        .frame(width: 200, height: 200)
                }
                
                // Gems
                HStack(spacing: 20) {
                    GemView(isActive: profile.ascend_subtier >= 1, color: tierColor, isObsidian: profile.ascend_tier.lowercased() == "obsidian")
                        .scaleEffect(animateGems ? 1 : 0.8)
                    
                    GemView(isActive: profile.ascend_subtier >= 2, color: tierColor, isObsidian: profile.ascend_tier.lowercased() == "obsidian")
                        .scaleEffect(animateGems ? 1 : 0.8)
                        .offset(y: -15) // Staggered look
                    
                    GemView(isActive: profile.ascend_subtier >= 3, color: tierColor, isObsidian: profile.ascend_tier.lowercased() == "obsidian")
                        .scaleEffect(animateGems ? 1 : 0.8)
                }
                .padding(.vertical, 40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: tierColor.opacity(0.1), radius: 20, y: 10)
            
            // Bottom Half: Details & Progress
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .bottom) {
                    Text("\(profile.ascend_tier) \(String(repeating: "I", count: profile.ascend_subtier))")
                        .font(DesignSystem.Typography.appFont(style: .title))
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(profile.ascend_xp)) points")
                            .font(DesignSystem.Typography.appFont(style: .headline))
                            .foregroundColor(textColor)
                    }
                }
                
                // Calculation for Progress
                // simplified for UI: show progress towards next subtier or tier
                AscendProgressBar(tierColor: tierColor, subtier: profile.ascend_subtier)
                
                HStack {
                    Text("\(profile.ascend_tier) I")
                        .font(DesignSystem.Typography.appFont(style: .caption2))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(profile.ascend_tier) II")
                        .font(DesignSystem.Typography.appFont(style: .caption2))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(profile.ascend_tier) III")
                        .font(DesignSystem.Typography.appFont(style: .caption2))
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    // Action to show history (future feature)
                }) {
                    Text("View point history")
                        .font(DesignSystem.Typography.appFont(style: .subheadline))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 10)
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
            .offset(y: -20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                animateGems = true
            }
        }
    }
}

// =========================================
// === GEM VIEW (Hexagon Shape) ===
// =========================================

struct GemView: View {
    var isActive: Bool
    var color: Color
    var isObsidian: Bool
    
    @State private var phase: Double = 0.0
    
    var body: some View {
        ZStack {
            // Shadow / Glow with breathing effect
            if isActive {
                HexagonShape()
                    .fill(isObsidian ? Color.purple : color)
                    .blur(radius: 12 + (sin(phase) * 4)) // Breath glow
                    .opacity(0.8)
            } else {
                HexagonShape()
                    .fill(color)
                    .blur(radius: 8)
                    .opacity(0.2)
            }
            
            HexagonShape()
                .fill(isActive ? color : color.opacity(0.15))
                .overlay(
                    HexagonShape()
                        .stroke(isActive ? Color.white.opacity(0.6) : color.opacity(0.3), lineWidth: isActive ? 2 : 1)
                )
            
            // Inner 3D highlights (Animated gradient shift)
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isActive ? (0.4 + (sin(phase) * 0.2)) : 0.1),
                            Color.clear,
                            Color.black.opacity(isActive ? 0.3 : 0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
                
            // Extra sharp bevel line
            if isActive {
                HexagonShape()
                    .stroke(
                        LinearGradient(
                            colors: [.white, .clear, .black],
                            startPoint: UnitPoint(x: 0.5 + cos(phase)*0.5, y: 0),
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .blendMode(.plusLighter)
            }
                
            if !isActive {
                HexagonShape()
                    .fill(Color.black.opacity(0.4))
            }
        }
        .frame(width: 50, height: 50)
        .rotation3DEffect(
            .degrees(isActive ? (sin(phase) * 10) : 0),
            axis: (x: 1.0, y: 0.5, z: 0.0)
        )
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    phase = .pi
                }
            }
        }
    }
}

// Custom Hexagon Shape for the Gems
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        
        let point1 = CGPoint(x: width * 0.5, y: 0)
        let point2 = CGPoint(x: width, y: height * 0.25)
        let point3 = CGPoint(x: width, y: height * 0.75)
        let point4 = CGPoint(x: width * 0.5, y: height)
        let point5 = CGPoint(x: 0, y: height * 0.75)
        let point6 = CGPoint(x: 0, y: height * 0.25)

        path.move(to: point1)
        path.addLine(to: point2)
        path.addLine(to: point3)
        path.addLine(to: point4)
        path.addLine(to: point5)
        path.addLine(to: point6)
        path.closeSubpath()
        
        return path
    }
}

// =========================================
// === PROGRESS BAR (Segmented) ===
// =========================================

struct AscendProgressBar: View {
    var tierColor: Color
    var subtier: Int
    
    @State private var animatedWidth1: CGFloat = 0
    @State private var animatedWidth2: CGFloat = 0
    @State private var animatedWidth3: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let segmentWidth = (geo.size.width - 10) / 3 // 2 gaps of 5
            
            HStack(spacing: 5) {
                // Segment 1
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(tierColor)
                        .frame(width: animatedWidth1)
                }
                .frame(width: segmentWidth, height: 8)
                
                // Segment 2
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(tierColor)
                        .frame(width: animatedWidth2)
                }
                .frame(width: segmentWidth, height: 8)
                
                // Segment 3
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(tierColor)
                        .frame(width: animatedWidth3)
                }
                .frame(width: segmentWidth, height: 8)
            }
            .onAppear {
                animateProgress(fullSegmentWidth: segmentWidth)
            }
        }
        .frame(height: 8)
    }
    
    private func animateProgress(fullSegmentWidth: CGFloat) {
        // Here we simulate the progress fill based on the current subtier.
        // For a true implementation, we'd calculate exact % of the current subtier level.
        // Since AscendProfile only gives subtier (1, 2, 3) we will fill up to that subtier.
        
        withAnimation(.easeOut(duration: 0.8)) {
            if subtier >= 1 { animatedWidth1 = fullSegmentWidth }
            if subtier >= 2 { animatedWidth2 = fullSegmentWidth }
            if subtier >= 3 { animatedWidth3 = fullSegmentWidth }
            
            // If they are exactly subtier 1, we fill segment 1 fully, and maybe animate segment 2 halfway
            // Since we don't have exact remainder XP in this view, we'll just fill fully for completed subtiers
            // and leave the current subtier halfway (for visual effect) - or you can bind this to actual xp progress.
        }
    }
}

// =========================================
// === EXTENDED RANK ROADMAP VIEW ===
// =========================================

struct RankRoadmapView: View {
    let currentLevel: Int
    
    // Grabbing the massive hierarchical array of tiers generated
    let tiers = AscendRoadmapData.shared.tiers
    
    @State private var selectedTier: RankTier? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(spacing: 0) {
                ForEach(tiers) { tier in
                    RankTierNodeView(tier: tier, currentLevel: currentLevel)
                        .id(tier.startLvl)
                        .onTapGesture {
                            selectedTier = tier
                        }
                }
            }
            .padding(.top, 10)
            .onAppear {
                // Auto scroll to current tier
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let currentOrLastTier = tiers.last(where: { currentLevel >= $0.startLvl })?.startLvl ?? 1
                    withAnimation {
                        proxy.scrollTo(currentOrLastTier, anchor: .center)
                    }
                }
            }
        }
        .sheet(item: $selectedTier) { tier in
            RankGallerySheet(tier: tier, currentLevel: currentLevel)
        }
    }
}

struct RankTierNodeView: View {
    let tier: RankTier
    let currentLevel: Int
    
    @State private var phase: Double = 0.0
    
    var body: some View {
        let isUnlocked = currentLevel >= tier.startLvl
        let isCurrentTier = currentLevel >= tier.startLvl && currentLevel <= tier.endLvl
        
        HStack(alignment: .top, spacing: 20) {
            // Vertical Timeline Line & Dot
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? tier.color : Color.gray.opacity(0.1))
                        .frame(width: 20, height: 20)
                        .shadow(color: isUnlocked ? tier.color.opacity(0.8) : .clear, radius: 8)
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.98), lineWidth: 3)
                        )
                    
                    if isCurrentTier {
                        Circle()
                            .stroke(tier.color, lineWidth: 2)
                            .frame(width: 30, height: 30)
                            .opacity(0.6 + (sin(phase) * 0.4))
                            .scaleEffect(1.0 + (sin(phase) * 0.2))
                    }
                }
                .frame(width: 30, height: 30) // WICHTIGER FIX: Feste Breite für exaktes Alignment der Striche!
                
                // Path line
                if tier.endLvl != 1000 {
                    Rectangle()
                        .fill(isUnlocked ? tier.color.opacity(0.6) : Color.gray.opacity(0.1))
                        .frame(width: 2)
                        .frame(height: 100)
                        .overlay(
                            Rectangle()
                                .fill(LinearGradient(colors: [.gray, .clear], startPoint: .top, endPoint: .bottom))
                                .frame(width: 2)
                                .opacity(isUnlocked && currentLevel > tier.endLvl ? 0.3 : 0) // Glowing flow
                        )
                }
            }
            .frame(width: 30) // Zwingt den gesamten Strich-Container exakt auf dieselbe Mitte
            
            // Content Card
            HStack(spacing: 15) {
                // Major Milestone uses the huge 3D Gem
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUnlocked ? tier.color.opacity(0.15) : Color.gray.opacity(0.05))
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isUnlocked ? tier.color.opacity(0.5) : Color.black.opacity(0.04), lineWidth: 1)
                        )
                    
                    GemView(isActive: isUnlocked, color: tier.color, isObsidian: tier.isObsidian)
                        .scaleEffect(0.6)
                        .shadow(color: isUnlocked ? tier.color.opacity(0.5) : .clear, radius: 10 + (sin(phase) * 5))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tier.name)
                            .font(DesignSystem.Typography.appFont(style: .headline))
                            .fontWeight(.bold)
                            .foregroundColor(isUnlocked ? .primary : .gray.opacity(0.6))
                        
                        if isCurrentTier {
                            Text("Current")
                                .font(DesignSystem.Typography.appFont(size: 10, weight: .bold))
                                .foregroundColor(tier.color)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(tier.color.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text("\(tier.achievements.count) Requirements")
                            .font(DesignSystem.Typography.appFont(style: .caption))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(DesignSystem.Typography.appFont(size: 9))
                                .foregroundColor(tier.color.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Chevron to indicate it's clickable
                Image(systemName: "chevron.right")
                    .font(DesignSystem.Typography.appFont(style: .footnote))
                    .foregroundColor(isUnlocked ? tier.color : .gray.opacity(0.4))
                    .padding(.trailing, 5)
            }
            .padding(15)
            .background(isCurrentTier ? tier.color.opacity(0.05) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCurrentTier ? tier.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .offset(y: -25)
        }
        .onAppear {
            if isCurrentTier {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    phase = .pi
                }
            }
        }
    }
}

// =========================================
// === RANK GALLERY SHEET ===
// =========================================

struct RankGallerySheet: View {
    let tier: RankTier
    let currentLevel: Int
    @Environment(\.dismiss) var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 15)
    ]
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()
            
            // Subtle ambient background
            Circle()
                .fill(RadialGradient(colors: [tier.color.opacity(0.12), Color.clear], center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .offset(y: -200)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(DesignSystem.Typography.appFont(style: .title2))
                            .foregroundColor(.primary.opacity(0.5))
                            .padding()
                    }
                    Spacer()
                    Text("\(tier.name) Records")
                        .font(DesignSystem.Typography.appFont(style: .headline))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "xmark").foregroundColor(.clear).padding()
                }
                .padding(.top, 10)
                
                // Stats summary
                let completedCount = tier.achievements.filter { currentLevel >= $0.levelReq }.count
                let progress = Double(completedCount) / Double(max(tier.achievements.count, 1))
                
                VStack(spacing: 8) {
                    Text("\(completedCount) / \(tier.achievements.count) COMPLETED")
                        .font(DesignSystem.Typography.appFont(style: .caption))
                        .fontWeight(.bold)
                        .foregroundColor(tier.color)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.1))
                            Capsule().fill(tier.color)
                                .frame(width: geo.size.width * CGFloat(progress))
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 25)
                
                // Grid of Achievements
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(tier.achievements) { ach in
                            let isUnlocked = currentLevel >= ach.levelReq
                            
                            VStack(spacing: 10) {
                                // Badge Graphic
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(isUnlocked ? tier.color.opacity(0.15) : Color.gray.opacity(0.05))
                                        .frame(height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(isUnlocked ? tier.color.opacity(0.4) : Color.black.opacity(0.04), lineWidth: 1)
                                        )
                                    
                                    Image(systemName: ach.icon)
                                        .font(DesignSystem.Typography.appFont(size: 28, weight: .light))
                                        .foregroundColor(isUnlocked ? tier.color : .gray.opacity(0.3))
                                        .shadow(color: isUnlocked ? tier.color.opacity(0.6) : .clear, radius: 5)
                                }
                                
                                // Text
                                VStack(spacing: 2) {
                                    Text(ach.title)
                                        .font(DesignSystem.Typography.appFont(style: .caption))
                                        .fontWeight(.bold)
                                        .foregroundColor(isUnlocked ? .primary : .gray.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                        
                                    Text(ach.subtitle)
                                        .font(DesignSystem.Typography.appFont(size: 9))
                                        .foregroundColor(isUnlocked ? tier.color.opacity(0.8) : .gray.opacity(0.4))
                                        .lineLimit(1)
                                }
                            }
                            .opacity(isUnlocked ? 1.0 : 0.6)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
