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
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text("Ascend Rank")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
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
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Unlock perks, rewards, and recognition as you level up your Ascend Rank.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 25)
                            .padding(.top, 15)
                            
                            // RANK ROADMAP
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Tier Progression")
                                    .font(.title2)
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 25)
                                
                                RankRoadmapView(currentLevel: profile.ascend_level)
                                    .padding(.horizontal, 25)
                            }
                            .padding(.top, 10)
                            
                        } else {
                            // Loading state or nil state
                            ProgressView().tint(.white)
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
        profile.ascend_tier.lowercased() == "obsidian" ? .white : tierColor
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // Top Half: Gems with Gradient Background
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.12),
                        tierColor.opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Obsidian Glow specific
                if profile.ascend_tier.lowercased() == "obsidian" {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .blur(radius: 40)
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
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(profile.ascend_xp)) points")
                            .font(.headline)
                            .foregroundColor(textColor)
                    }
                }
                
                // Calculation for Progress
                // simplified for UI: show progress towards next subtier or tier
                AscendProgressBar(tierColor: tierColor, subtier: profile.ascend_subtier)
                
                HStack {
                    Text("\(profile.ascend_tier) I")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(profile.ascend_tier) II")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(profile.ascend_tier) III")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    // Action to show history (future feature)
                }) {
                    Text("View point history")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 10)
            }
            .padding(20)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .offset(y: -20) // Overlap top section slightly
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
    
    // Grabbing the massive array of achievements generated
    let nodes = AscendRoadmapData.shared.nodes
    
    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(spacing: 0) {
                ForEach(nodes) { node in
                    AchievementNodeView(node: node, currentLevel: currentLevel)
                        .id(node.levelReq)
                }
            }
            .padding(.top, 10)
            .onAppear {
                // Auto scroll to current level with slight delay for layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        proxy.scrollTo(currentLevel, anchor: .center)
                    }
                }
            }
        }
    }
}

struct AchievementNodeView: View {
    let node: RoadmapNode
    let currentLevel: Int
    
    @State private var phase: Double = 0.0
    
    var body: some View {
        let isUnlocked = currentLevel >= node.levelReq
        let isCurrent = currentLevel == node.levelReq
        
        HStack(alignment: .top, spacing: 20) {
            // Vertical Timeline Line & Dot
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? node.tierColor : Color.white.opacity(0.1))
                        .frame(width: node.isMajorMilestone ? 20 : 12, height: node.isMajorMilestone ? 20 : 12)
                        .shadow(color: isUnlocked ? node.tierColor.opacity(0.8) : .clear, radius: 8)
                        .overlay(
                            Circle()
                                .stroke(Color(red: 0.05, green: 0.05, blue: 0.08), lineWidth: 3) // cutout
                        )
                    
                    if isCurrent {
                        Circle()
                            .stroke(node.tierColor, lineWidth: 2)
                            .frame(width: node.isMajorMilestone ? 30 : 20, height: node.isMajorMilestone ? 30 : 20)
                            .opacity(0.6 + (sin(phase) * 0.4))
                            .scaleEffect(1.0 + (sin(phase) * 0.2))
                    }
                }
                
                // Don't draw path line for the very last item in the entire game
                if node.levelReq != 1000 {
                    Rectangle()
                        .fill(isUnlocked ? node.tierColor.opacity(0.6) : Color.white.opacity(0.1))
                        .frame(width: 2)
                        .frame(height: node.isMajorMilestone ? 100 : 70) // Path length
                        .overlay(
                            // Optional glowing flow effect for unlocked path
                                Rectangle()
                                .fill(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 2)
                                    .opacity(isUnlocked && currentLevel > node.levelReq ? 0.3 : 0)
                        )
                }
            }
            
            // Content Card
            HStack(spacing: 15) {
                if node.isMajorMilestone {
                    // Major Milestone uses the huge 3D Gem
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isUnlocked ? node.tierColor.opacity(0.15) : Color.white.opacity(0.03))
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isUnlocked ? node.tierColor.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                            )
                        
                        GemView(isActive: isUnlocked, color: node.tierColor, isObsidian: node.isObsidian)
                            .scaleEffect(0.6)
                            .shadow(color: isUnlocked ? node.tierColor.opacity(0.5) : .clear, radius: 10 + (sin(phase) * 5))
                    }
                } else {
                    // Minor milestones use a smaller icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 40, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isUnlocked ? node.tierColor.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                            )
                        
                        Image(systemName: node.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isUnlocked ? .white : .gray.opacity(0.4))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(node.title)
                            .font(node.isMajorMilestone ? .headline : .subheadline)
                            .fontWeight(node.isMajorMilestone ? .bold : .semibold)
                            .foregroundColor(isUnlocked ? .white : .gray.opacity(0.6))
                        
                        if isCurrent {
                            Text("Current")
                                .font(.system(size: node.isMajorMilestone ? 10 : 9, weight: .bold))
                                .foregroundColor(node.tierColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(node.tierColor.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(node.subtitle)
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.5))
                        
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(node.tierColor.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                if isUnlocked && !isCurrent {
                    Image(systemName: "checkmark")
                        .font(.footnote)
                        .foregroundColor(.green.opacity(0.8))
                        .padding(.trailing, 5)
                } else if !isUnlocked {
                    Text("Lvl \(node.levelReq)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(node.tierColor.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(node.tierColor.opacity(0.05))
                        .clipShape(Capsule())
                }
            }
            .padding(node.isMajorMilestone ? 15 : 10)
            .background(isCurrent ? node.tierColor.opacity(0.05) : Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: node.isMajorMilestone ? 16 : 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: node.isMajorMilestone ? 16 : 12, style: .continuous)
                    .stroke(isCurrent ? node.tierColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .offset(y: node.isMajorMilestone ? -25 : -15) // Align card with the dot center
        }
        .onAppear {
            if isCurrent {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    phase = .pi
                }
            }
        }
    }
}
