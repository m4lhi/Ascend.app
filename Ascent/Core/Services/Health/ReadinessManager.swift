import Foundation
import Combine
import SwiftUI

// =========================================
// === DATEI: ReadinessManager.swift ===
// === High-Altitude Readiness Engine ===
// =========================================

struct ReadinessBreakdown: Codable {
    var totalScore: Int          // 0-100
    var physiologicalScore: Int  // Trends (HRV, RHR, SpO2)
    var workloadScore: Int       // ACWR (Acute:Chronic Workload)
    var altitudeScore: Int       // Acclimatization
    var environmentScore: Int    // Goal Weather & Conditions
    
    var status: String
    var recommendation: String
    var details: [String]
}

@MainActor
class ReadinessManager: ObservableObject {
    static let shared = ReadinessManager()
    
    @Published var currentReadiness: ReadinessBreakdown?
    
    func calculate(profile: HealthKitProfile, tours: [Tour], targetMountain: Mountain?, targetWeather: MountainWeather?, extendedAnswers: [String: [String]] = [:]) -> ReadinessBreakdown {

        // 1. PHYSIOLOGY (40%)
        let phys = calculatePhysiologicalScore(profile, answers: extendedAnswers)
        
        // 2. WORKLOAD (30%)
        let load = calculateWorkloadScore(tours)
        
        // 3. ALTITUDE (20%)
        let alt = calculateAltitudeScore(tours)
        
        // 4. ENVIRONMENT (10%)
        let env = calculateEnvironmentScore(targetMountain, targetWeather)
        
        let total = (phys.score * 40 + load.score * 30 + alt.score * 20 + env.score * 10) / 100
        
        let status = getStatus(total)
        let recommendation = getRecommendation(total, load: load.status, phys: phys.status)
        
        var details: [String] = []
        details.append(phys.detail)
        details.append(load.detail)
        if !alt.detail.isEmpty { details.append(alt.detail) }
        if !env.detail.isEmpty { details.append(env.detail) }
        
        return ReadinessBreakdown(
            totalScore: total,
            physiologicalScore: phys.score,
            workloadScore: load.score,
            altitudeScore: alt.score,
            environmentScore: env.score,
            status: status,
            recommendation: recommendation,
            details: details
        )
    }
    
    // MARK: - Private Calculators
    
    private func calculatePhysiologicalScore(_ p: HealthKitProfile, answers: [String: [String]] = [:]) -> (score: Int, status: String, detail: String) {
        var score = 75 // Baseline
        var details: [String] = []

        // Subjective self-report — fold the user's check-in into the
        // physiological score. Two flavours of input:
        //   1. Quick variant writes the "overall" key with one word.
        //   2. Detail variant writes five keys (sleep/energy/legs/
        //      focus/hr); we aggregate them to a synthesized nudge.
        // When HRV is missing entirely the self-report becomes the
        // baseline. When HRV is present the answer nudges the score
        // by half so HealthKit still anchors it.
        if let nudgeInfo = selfReportNudge(answers: answers) {
            let (nudge, label) = nudgeInfo
            if p.heartRateVariability == nil {
                score = 75 + nudge
                details.append("Self-report: \(label)")
            } else {
                score += nudge / 2
            }
        }

        // HRV impact
        if let hrv = p.heartRateVariability {
            if hrv < 30 { score -= 15; details.append("Low HRV (Recovery potential low)") }
            else if hrv > 60 { score += 10; details.append("High HRV (Ready for load)") }
        }

        // SpO2 impact
        if let spo2 = p.bloodOxygenSaturation {
            if spo2 < 92 { score -= 25; details.append("Low Blood Oxygen (Critical for altitude)") }
            else if spo2 < 95 { score -= 10; details.append("Sub-optimal Oxygenation") }
            else { score += 5; details.append("Great Oxygen Saturation") }
        }

        // RHR impact
        if let rhr = p.restingHeartRate {
            if rhr > 75 { score -= 10; details.append("Elevated Resting HR") }
            else if rhr < 55 { score += 5; details.append("Efficient Cardiovascular state") }
        }

        return (max(0, min(100, score)), score > 70 ? "Stable" : "Stressed", details.first ?? "Body systems active")
    }
    
    /// Returns the score nudge + a display label from the user's
    /// extendedReadinessAnswers. Quick "overall" wins when present;
    /// otherwise the five detail keys average onto a 1–4 scale and
    /// pick a band. Returns nil if no relevant answer exists.
    private func selfReportNudge(answers: [String: [String]]) -> (nudge: Int, label: String)? {
        if let overall = answers["overall"]?.first {
            let nudge: Int
            switch overall {
            case "Strong":  nudge = 12
            case "Okay":    nudge = 4
            case "Tired":   nudge = -12
            case "Drained": nudge = -28
            default:        nudge = 0
            }
            return (nudge, overall)
        }

        let detailKeys = ["sleep", "energy", "legs", "focus", "hr"]
        let words = detailKeys.compactMap { answers[$0]?.first }
        guard !words.isEmpty else { return nil }
        let scored = words.map { word -> Int in
            switch word {
            case "Restored", "Strong", "Fresh", "Sharp", "Calm":  return 4
            case "Okay", "Normal":                                return 3
            case "Light", "Low", "Sore", "Foggy", "Elevated":     return 2
            case "Barely slept", "Drained", "Heavy", "Scattered": return 1
            default:                                              return 3
            }
        }
        let avg = Double(scored.reduce(0, +)) / Double(scored.count)
        let nudge: Int
        let label: String
        switch avg {
        case 3.5...:    nudge = 12;  label = "Strong"
        case 2.5..<3.5: nudge = 4;   label = "Okay"
        case 1.5..<2.5: nudge = -12; label = "Tired"
        default:        nudge = -28; label = "Drained"
        }
        return (nudge, label)
    }

    private func calculateWorkloadScore(_ tours: [Tour]) -> (score: Int, status: String, detail: String) {
        let calendar = Calendar.current
        let now = Date()
        
        let last7Days = tours.filter { calendar.dateComponents([.day], from: $0.date, to: now).day ?? 100 <= 7 }
        let last28Days = tours.filter { calendar.dateComponents([.day], from: $0.date, to: now).day ?? 100 <= 28 }
        
        let acuteLoad = last7Days.reduce(0) { $0 + Double($1.elevationGainMeters) }
        let chronicLoad = (last28Days.reduce(0) { $0 + Double($1.elevationGainMeters) }) / 4.0
        
        if chronicLoad < 100 {
            return (70, "Neutral", "Insufficient training history for ACWR")
        }
        
        let ratio = acuteLoad / max(chronicLoad, 1)
        
        if ratio > 1.3 {
            return (40, "Overreaching", "High load increase (+ \(Int((ratio-1)*100))%). Risk of injury.")
        } else if ratio < 0.8 {
            return (60, "Detraining", "Training volume dropped. Readiness high, but fitness may fade.")
        } else {
            return (95, "Optimal", "Perfect training progression (Ratio: \(String(format: "%.1f", ratio)))")
        }
    }
    
    private func calculateAltitudeScore(_ tours: [Tour]) -> (score: Int, detail: String) {
        // Simple mock for now: Check if any tour in last 7 days was > 2500m
        let highTours = tours.filter { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 100 <= 7 && $0.elevationGainMeters > 2000 }
        
        if highTours.isEmpty {
            return (50, "No recent altitude exposure detected.")
        } else {
            return (100, "Recent altitude acclimatization confirmed.")
        }
    }
    
    private func calculateEnvironmentScore(_ mountain: Mountain?, _ weather: MountainWeather?) -> (score: Int, detail: String) {
        guard let mountain = mountain, let weather = weather else {
            return (100, "") // No target = no penalty
        }
        
        var score = 100
        var detail = ""
        
        if weather.windSpeed > 60 {
            score -= 40
            detail = "Danger: High Winds on \(mountain.name)"
        } else if weather.precipitationChance > 0.7 {
            score -= 20
            detail = "Weather Front: High rain/snow risk"
        }
        
        if weather.temperature < -15 {
            score -= 20
            detail = "Extreme Cold front approaching"
        }
        
        return (max(0, score), detail)
    }
    
    private func getStatus(_ score: Int) -> String {
        if score > 85 { return "Peak Readiness" }
        if score > 70 { return "Good to Go" }
        if score > 50 { return "Moderate Readiness" }
        return "Caution Required"
    }
    
    private func getRecommendation(_ score: Int, load: String, phys: String) -> String {
        if score < 50 { return "Rest and recover. Physiological stress detected." }
        if load == "Overreaching" { return "High injury risk. Suggest light active recovery only." }
        if score > 85 { return "Perfect window for your summit push." }
        return "Suitable for moderate training volume."
    }
}
