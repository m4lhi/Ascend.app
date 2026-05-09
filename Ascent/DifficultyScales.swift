import SwiftUI

// =========================================
// === Real climbing difficulty scales ===
// =========================================
// Adds proper alpinist scales (UIAA, SAC, WI Eis) on top of the existing
// internal Easy/Medium/Hard/Extreme/Expert system. The internal scale is
// kept for backward compatibility; new features can opt into the precise scales.

enum AlpineGradeKind: String, CaseIterable, Codable {
    case sacHiking      = "SAC Hiking"      // T1–T6 (Schweizerischer Alpen-Club)
    case sacSkitour     = "SAC Skitour"     // L, WS, ZS, S, SS, AS, EX
    case uiaaRock       = "UIAA"            // I, II, III, IV, V, VI, VII, VIII, IX, X, XI
    case wiIce          = "WI Eis"          // WI1, WI2, ... WI7
    case alpineOverall  = "Alpine"          // F, PD, AD, D, TD, ED, ABO

    var symbol: String {
        switch self {
        case .sacHiking:     return "figure.hiking"
        case .sacSkitour:    return "figure.skiing.downhill"
        case .uiaaRock:      return "figure.climbing"
        case .wiIce:         return "snowflake"
        case .alpineOverall: return "mountain.2.fill"
        }
    }
}

// All values for each scale, in order from easy to hard.
enum AlpineGradeValue {
    static let sacHiking      = ["T1", "T2", "T3", "T4", "T5", "T6"]
    static let sacSkitour     = ["L", "WS", "ZS", "S", "SS", "AS", "EX"]
    static let uiaaRock       = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
    static let wiIce          = ["WI1", "WI2", "WI3", "WI4", "WI5", "WI6", "WI7"]
    static let alpineOverall  = ["F", "PD", "AD", "D", "TD", "ED", "ABO"]

    /// All grade values for a kind.
    static func values(for kind: AlpineGradeKind) -> [String] {
        switch kind {
        case .sacHiking:     return sacHiking
        case .sacSkitour:    return sacSkitour
        case .uiaaRock:      return uiaaRock
        case .wiIce:         return wiIce
        case .alpineOverall: return alpineOverall
        }
    }
}

/// Single grade entry — kind + the specific value within that kind.
/// e.g. (kind: .sacHiking, value: "T4")
struct AlpineGrade: Codable, Hashable, Identifiable {
    var id: String { "\(kind.rawValue):\(value)" }
    var kind: AlpineGradeKind
    var value: String

    /// Fraction along its scale, 0–1 (used for color interpolation).
    var difficultyFraction: Double {
        let all = AlpineGradeValue.values(for: kind)
        guard let idx = all.firstIndex(of: value), all.count > 1 else { return 0 }
        return Double(idx) / Double(all.count - 1)
    }

    var color: Color {
        let f = difficultyFraction
        // Green (easy) → Yellow → Orange → Red → Purple (extreme)
        if f < 0.25 {       return .green }
        else if f < 0.50 {  return .yellow }
        else if f < 0.70 {  return .orange }
        else if f < 0.88 {  return .red }
        else {              return .purple }
    }
}

// MARK: - Mapping from internal Difficulty to default Alpine grades

extension Difficulty {
    /// Best-effort mapping from the legacy Easy/Medium/Hard/Extreme/Expert to
    /// SAC Hiking + Alpine Overall (the two most universal scales).
    /// Used as default until users assign more precise grades manually.
    var defaultAlpineGrades: [AlpineGrade] {
        switch self {
        case .easy:
            return [
                AlpineGrade(kind: .sacHiking,     value: "T2"),
                AlpineGrade(kind: .alpineOverall, value: "F")
            ]
        case .medium:
            return [
                AlpineGrade(kind: .sacHiking,     value: "T3"),
                AlpineGrade(kind: .alpineOverall, value: "PD")
            ]
        case .hard:
            return [
                AlpineGrade(kind: .sacHiking,     value: "T4"),
                AlpineGrade(kind: .alpineOverall, value: "AD"),
                AlpineGrade(kind: .uiaaRock,      value: "III")
            ]
        case .extreme:
            return [
                AlpineGrade(kind: .sacHiking,     value: "T5"),
                AlpineGrade(kind: .alpineOverall, value: "D"),
                AlpineGrade(kind: .uiaaRock,      value: "IV")
            ]
        case .expert:
            return [
                AlpineGrade(kind: .sacHiking,     value: "T6"),
                AlpineGrade(kind: .alpineOverall, value: "TD"),
                AlpineGrade(kind: .uiaaRock,      value: "V")
            ]
        }
    }

    /// Short prose summary appropriate for the level.
    var alpineDescription: String {
        switch self {
        case .easy:    return "Marked trails, no exposure. Sturdy shoes are enough."
        case .medium:  return "Steeper, often rocky. Sure-footedness required."
        case .hard:    return "Exposed sections, occasional easy climbing. Helmet recommended."
        case .extreme: return "Sustained alpine terrain. Rope, harness, and rock skills required."
        case .expert:  return "Serious mountaineering. Glacier, ice, or sustained UIAA IV+."
        }
    }
}

// MARK: - Compact UI badge

struct AlpineGradeBadge: View {
    let grade: AlpineGrade
    var size: Size = .medium

    enum Size { case small, medium, large }

    private var horizontalPad: CGFloat {
        switch size {
        case .small: return 7
        case .medium: return 9
        case .large: return 12
        }
    }
    private var verticalPad: CGFloat {
        switch size {
        case .small: return 3
        case .medium: return 4
        case .large: return 6
        }
    }
    private var fontSize: CGFloat {
        switch size {
        case .small: return 9
        case .medium: return 10
        case .large: return 13
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: grade.kind.symbol)
                .font(.system(size: fontSize - 1, weight: .heavy))
            Text(grade.value)
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .tracking(0.4)
        }
        .foregroundColor(.white)
        .padding(.horizontal, horizontalPad)
        .padding(.vertical, verticalPad)
        .background(
            Capsule().fill(grade.color)
        )
        .overlay(
            Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Group of grade badges (multiple scales side-by-side)

struct AlpineGradesRow: View {
    let grades: [AlpineGrade]
    var size: AlpineGradeBadge.Size = .medium

    var body: some View {
        HStack(spacing: 6) {
            ForEach(grades) { grade in
                AlpineGradeBadge(grade: grade, size: size)
            }
        }
    }
}
