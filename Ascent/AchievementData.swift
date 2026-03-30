import Foundation
import SwiftUI

struct RoadmapNode: Identifiable {
    let id = UUID()
    let levelReq: Int
    let title: String
    let subtitle: String
    let icon: String
    let isMajorMilestone: Bool
    let tierColor: Color
    let isObsidian: Bool
}

class AscendRoadmapData {
    static let shared = AscendRoadmapData()
    
    lazy var nodes: [RoadmapNode] = generateRoadmap()
    
    private func generateRoadmap() -> [RoadmapNode] {
        var generatedNodes: [RoadmapNode] = []
        
        // Define the tiers and their starting levels.
        let tiers: [(name: String, startLvl: Int, endLvl: Int, color: Color, isObsidian: Bool)] = [
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
            ("Summit Seeker", "Reach an altitude of ", "m", "mountain.2"),
            ("Distance Hiker", "Log ", "km total distance", "figure.walk"),
            ("Endurance Climber", "Climb for ", " hours straight", "figure.climbing"),
            ("Heart Rate Zone", "Maintain 140bpm for ", " mins", "heart.fill"),
            ("Peak Explorer", "Discover ", " new peaks", "map.fill"),
            ("Alpine Veteran", "Complete ", " difficult routes", "star.circle.fill"),
            ("Early Bird", "Start ", " hikes before sunrise", "sun.and.horizon.fill"),
            ("Glacier Walker", "Cross ", "km of ice fields", "snowflake")
        ]
        
        for (tierIndex, tier) in tiers.enumerated() {
            for level in tier.startLvl...tier.endLvl {
                
                // If it's the exact starting level of the tier, it's a Major Milestone
                if level == tier.startLvl {
                    generatedNodes.append(RoadmapNode(
                        levelReq: level,
                        title: tier.name,
                        subtitle: tier.isObsidian ? "The Pinnacle of Alpinism" : "Rank Promotion",
                        icon: "shield.fill",
                        isMajorMilestone: true,
                        tierColor: tier.color,
                        isObsidian: tier.isObsidian
                    ))
                } else {
                    // It's a minor achievement milestone for every other level! This ensures 60+ per major rank!
                    
                    // Procedurally generate the achievement text
                    let t = templates[(level * 13) % templates.count] // deterministic shuffle
                    let difficultyMultiplier = level
                    
                    let quantity: Int
                    if t.0 == "Summit Seeker" { quantity = 500 + difficultyMultiplier * 10 }
                    else if t.0 == "Distance Hiker" { quantity = 5 + difficultyMultiplier / 5 }
                    else if t.0 == "Endurance Climber" { quantity = 1 + difficultyMultiplier / 50 }
                    else if t.0 == "Heart Rate Zone" { quantity = 10 + difficultyMultiplier / 10 }
                    else if t.0 == "Alpine Veteran" { quantity = 1 + difficultyMultiplier / 20 }
                    else if t.0 == "Early Bird" { quantity = 1 + difficultyMultiplier / 15 }
                    else if t.0 == "Glacier Walker" { quantity = 1 + difficultyMultiplier / 25 }
                    else { quantity = 1 + (difficultyMultiplier / 10) }
                    
                    generatedNodes.append(RoadmapNode(
                        levelReq: level,
                        title: "Level \(level): \(t.0)",
                        subtitle: t.1 + "\(quantity)" + t.2,
                        icon: t.3,
                        isMajorMilestone: false,
                        tierColor: tier.color.opacity(0.7), // Slightly dimmer color for minor nodes
                        isObsidian: tier.isObsidian
                    ))
                }
            }
        }
        
        return generatedNodes
    }
}
