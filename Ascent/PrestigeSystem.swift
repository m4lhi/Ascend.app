//
//  PrestigeSystem.swift
//  Ascent
//
//  Core data models for the prestige and ranking system.
//  Contains: Ranks, XP-Calculation, and Leaderboard Models.
//

import SwiftUI

// =========================================
// === EXTENSIONS FOR EXISTING MODELS ======
// =========================================
// Fügt dem Difficulty-Enum aus der MountainDatabase die XP-Logik hinzu
extension Difficulty {
    var xpMultiplier: Double {
        switch self {
        case .easy:    return 1.0
        case .medium:  return 1.5
        case .hard:    return 2.2
        case .extreme: return 3.5
        }
    }

    var description: String {
        switch self {
        case .easy:    return "Easy hiking trails, no climbing involved"
        case .medium:  return "Partly steep terrain, simple climbing sections"
        case .hard:    return "Exposed sections, via ferrata passages"
        case .extreme: return "High alpine terrain, glacier equipment required"
        }
    }
}

// =========================================
// === RANK TITLES (Level System) ==========
// =========================================
enum RankTitle: String {
    case wanderer      = "Wanderer"
    case mountaineer   = "Mountaineer"
    case alpinist      = "Alpinist"
    case expeditionist = "Expeditionist"
    case legend        = "Legend"

    static func forLevel(_ level: Int) -> RankTitle {
        switch level {
        case 1...5:   return .wanderer
        case 6...10:  return .mountaineer
        case 11...15: return .alpinist
        case 16...20: return .expeditionist
        default:      return .legend
        }
    }

    var icon: String {
        switch self {
        case .wanderer:      return "figure.walk"
        case .mountaineer:   return "figure.hiking"
        case .alpinist:      return "triangle.fill"
        case .expeditionist: return "star.circle.fill"
        case .legend:        return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .wanderer:      return .systemGreen
        case .mountaineer:   return DesignSystem.Colors.accent
        case .alpinist:      return Color(red: 0.50, green: 0.10, blue: 0.88)
        case .expeditionist: return DesignSystem.Colors.prestige
        case .legend:        return Color(red: 0.88, green: 0.18, blue: 0.55)
        }
    }

    var levelRange: String {
        switch self {
        case .wanderer:      return "Level 1–5"
        case .mountaineer:   return "Level 6–10"
        case .alpinist:      return "Level 11–15"
        case .expeditionist: return "Level 16–20"
        case .legend:        return "Level 21+"
        }
    }
}

// =========================================
// === XP CALCULATION ======================
// =========================================
enum XPCalculator {

    // Calculates XP for a single tour
    static func xp(elevation: Int, difficulty: Difficulty, isPrestigePeak: Bool) -> Int {
        let base           = Double(elevation) * 0.12
        let withDifficulty = base * difficulty.xpMultiplier
        let withPrestige   = isPrestigePeak ? withDifficulty * 1.3 : withDifficulty
        return max(50, Int(withPrestige))
    }

    // XP required to reach a specific level
    static func requiredXP(forLevel level: Int) -> Int {
        1_000 + (level - 1) * 500
    }

    // Prestige score for an ascent (0-100)
    static func prestigeScore(elevation: Int, durationMinutes: Int, difficulty: Difficulty) -> Int {
        let elevationPoints = min(Double(elevation) / 38.0, 40.0)
        let speedPoints: Double = durationMinutes > 0
            ? min(Double(elevation) / Double(durationMinutes) * 8.0, 40.0)
            : 20.0
        let difficultyBonus = difficulty.xpMultiplier * 5.0
        return min(Int(elevationPoints + speedPoints + difficultyBonus), 100)
    }
}

// =========================================
// === LEADERBOARD ENTRIES =================
// =========================================

struct GlobalRankEntry: Identifiable {
    let id             = UUID()
    let rank:          Int
    let userName:      String
    let level:         Int
    let totalXP:       Int
    let totalAscents:  Int
    let prestigeScore: Int
    let topTier:       PrestigeTier
    let isCurrentUser: Bool

    var rankTitle: RankTitle { RankTitle.forLevel(level) }
}

struct MountainRankEntry: Identifiable {
    let id            = UUID()
    let rank:         Int
    let userName:     String
    let level:        Int
    let score:        Int
    let tier:         PrestigeTier
    let ascents:      Int
    let bestTime:     String?
    let isCurrentUser:Bool
}
