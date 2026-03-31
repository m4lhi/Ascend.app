import Foundation
import SwiftUI

struct RankAchievement: Identifiable {
    let id = UUID()
    let levelReq: Int
    let title: String
    let subtitle: String
    let icon: String
}

struct RankTier: Identifiable {
    let id = UUID()
    let name: String
    let startLvl: Int
    let endLvl: Int
    let color: Color
    let isObsidian: Bool
    let achievements: [RankAchievement]
}

class AscendRoadmapData {
    static let shared = AscendRoadmapData()
    
    lazy var tiers: [RankTier] = generateTiers()
    
    private func generateTiers() -> [RankTier] {
        var generatedTiers: [RankTier] = []
        
        // Define the 13 major ranks
        let rankDefinitions: [(name: String, startLvl: Int, endLvl: Int, color: Color, isObsidian: Bool)] = [
            ("Bronze I", 1, 50, Color(red: 0.8, green: 0.45, blue: 0.15), false),
            ("Bronze II", 51, 100, Color(red: 0.8, green: 0.45, blue: 0.15), false),
            ("Bronze III", 101, 150, Color(red: 0.8, green: 0.45, blue: 0.15), false),
            
            ("Silver I", 151, 200, Color(red: 0.7, green: 0.75, blue: 0.8), false),
            ("Silver II", 201, 250, Color(red: 0.7, green: 0.75, blue: 0.8), false),
            ("Silver III", 251, 300, Color(red: 0.7, green: 0.75, blue: 0.8), false),
            
            ("Gold I", 301, 366, Color(red: 0.95, green: 0.8, blue: 0.2), false),
            ("Gold II", 367, 433, Color(red: 0.95, green: 0.8, blue: 0.2), false),
            ("Gold III", 434, 500, Color(red: 0.95, green: 0.8, blue: 0.2), false),
            
            ("Platinum I", 501, 600, Color(red: 0.7, green: 0.5, blue: 0.95), false),
            ("Platinum II", 601, 700, Color(red: 0.7, green: 0.5, blue: 0.95), false),
            ("Platinum III", 701, 800, Color(red: 0.7, green: 0.5, blue: 0.95), false),
            
            ("Obsidian", 801, 1000, Color.purple, true)
        ]
        
        let templates = [
            ("Summit Seeker", "Reach an altitude of ", "m", "mountain.2.fill"),
            ("Distance Hiker", "Log ", "km total distance", "figure.walk"),
            ("Endurance Climber", "Climb for ", " hours straight", "figure.climbing"),
            ("Heart Rate Zone", "Maintain 140bpm for ", " mins", "heart.fill"),
            ("Peak Explorer", "Discover ", " new peaks", "map.fill"),
            ("Alpine Veteran", "Complete ", " difficult routes", "star.circle.fill"),
            ("Early Bird", "Start ", " hikes before sunrise", "sun.and.horizon.fill"),
            ("Glacier Walker", "Cross ", "km of ice fields", "snowflake")
        ]
        
        for def in rankDefinitions {
            var achievements: [RankAchievement] = []
            
            // Generate the specific 50-100 achievements for this specific rank's gallery
            for level in (def.startLvl + 1)...def.endLvl {
                let t = templates[(level * 17) % templates.count] // deterministic shuffle
                let multiplier = level
                
                let quantity: Int
                if t.0 == "Summit Seeker" { quantity = 500 + multiplier * 15 }
                else if t.0 == "Distance Hiker" { quantity = 5 + multiplier / 4 }
                else if t.0 == "Endurance Climber" { quantity = 1 + multiplier / 40 }
                else if t.0 == "Heart Rate Zone" { quantity = 10 + multiplier / 8 }
                else if t.0 == "Alpine Veteran" { quantity = 1 + multiplier / 15 }
                else if t.0 == "Early Bird" { quantity = 1 + multiplier / 12 }
                else if t.0 == "Glacier Walker" { quantity = 1 + multiplier / 20 }
                else { quantity = 1 + (multiplier / 10) }
                
                let numeral = multiplier/20 > 0 ? Array(repeating: "I", count: multiplier/20 % 3 + 1).joined() : "I"
                
                achievements.append(RankAchievement(
                    levelReq: level,
                    title: "\(t.0) \(numeral)",
                    subtitle: t.1 + "\(quantity)" + t.2,
                    icon: t.3
                ))
            }
            
            generatedTiers.append(RankTier(
                name: def.name,
                startLvl: def.startLvl,
                endLvl: def.endLvl,
                color: def.color,
                isObsidian: def.isObsidian,
                achievements: achievements
            ))
        }
        
        return generatedTiers
    }
}
