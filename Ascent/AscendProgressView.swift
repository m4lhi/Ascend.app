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
    
    var body: some View {
        ZStack {
            // Shadow / Glow
            if isActive {
                HexagonShape()
                    .fill(isObsidian ? Color.purple : color)
                    .blur(radius: 12)
                    .opacity(0.5)
            }
            
            HexagonShape()
                .fill(isActive ? color : Color.white.opacity(0.1))
                .overlay(
                    HexagonShape()
                        .stroke(isActive ? Color.white.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                )
            
            // Inner 3D highlights
            if isActive {
                HexagonShape()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.clear, Color.black.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            }
        }
        .frame(width: 50, height: 50)
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
