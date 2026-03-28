import Foundation
import SwiftUI

// === 1. ENUMS (Jetzt Codable für JSON) ===
enum Difficulty: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case extreme = "Extreme"

    var color: Color {
        switch self {
        case .easy:    return .green
        case .medium:  return .blue
        case .hard:    return .orange
        case .extreme: return .red
        }
    }
}

// === 2. MOUNTAIN MODEL (Jetzt Codable) ===
struct Mountain: Identifiable, Hashable, Codable {
    var id = UUID() // Wird automatisch generiert, muss nicht ins JSON!
    let name: String
    let elevation: Int
    let difficulty: Difficulty
    let country: String
    let region: String
    let description: String
    let isPrestigePeak: Bool
    // === NEU: BILD-URL (Optional) ===
    let imageUrl: String?
    var photographer_name: String?
    var photographer_link: String?
    // NEU: Optionale Koordinaten (Optional, weil manche Berge vielleicht noch keine haben) [cite: 2026-03-07]
    let latitude: Double?
    let longitude: Double?
    
    // Sagt der App, welche Felder im JSON stehen
    enum CodingKeys: String, CodingKey {
        case name, elevation, difficulty, country, region, description, isPrestigePeak, imageUrl
        case photographer_name, photographer_link, latitude, longitude    }

    var elevationFormatted: String {
        "\(elevation)m"
    }

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [DesignSystem.Colors.accent, Color.blue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// === PRESTIGE MODEL (Bleibt wie es ist) ===
struct UserMountainPrestige: Identifiable {
    let id = UUID()
    let mountain: Mountain
    var ascents: Int
    var bestTime: String?
    var score: Int
    var tier: PrestigeTier
}

enum PrestigeTier {
    case none, bronze, silver, gold, platinum, elite
    
    var label: String {
        switch self {
        case .none: return "Unranked"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .elite: return "Elite"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "circle.dashed"
        case .bronze, .silver, .gold: return "medal.fill"
        case .platinum: return "star.circle.fill"
        case .elite: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return DesignSystem.Colors.tertiaryText
        case .bronze: return Color.brown
        case .silver: return Color.gray
        case .gold: return Color.yellow
        case .platinum: return Color.cyan
        case .elite: return DesignSystem.Colors.prestige
        }
    }
    
    var minimumScore: Int {
        switch self {
        case .none: return 0
        case .bronze: return 10
        case .silver: return 25
        case .gold: return 50
        case .platinum: return 75
        case .elite: return 100
        }
    }
    
    var next: PrestigeTier? {
        switch self {
        case .none: return .bronze
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .platinum
        case .platinum: return .elite
        case .elite: return nil
        }
    }
}

// =========================================
// === THE DATABASE (JSON LOADER) ===
// =========================================
struct MountainDatabase {
    
    static let mockUserPrestige: [UserMountainPrestige] = []

    // Lädt die Berge jetzt automatisch aus der JSON-Datei!
    static let all: [Mountain] = loadMountains()

    static var prestigePeaks: [Mountain] {
        all.filter { $0.isPrestigePeak }
    }
    
    // Die magische Lade-Funktion
    private static func loadMountains() -> [Mountain] {
        guard let url = Bundle.main.url(forResource: "mountains", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ FEHLER: mountains.json nicht gefunden!")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let mountains = try decoder.decode([Mountain].self, from: data)
            return mountains
        } catch {
            print("❌ FEHLER beim Lesen der JSON: \(error)")
            return []
        }
    }
}
