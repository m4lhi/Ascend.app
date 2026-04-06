import Foundation
import Combine
import CoreLocation
import AVFoundation
import MapKit
import SwiftUI

// =========================================
// === DATEI: NavigationManager.swift ===
// === Turn-by-Turn Navigation Engine ===
// =========================================

struct NavigationInstruction: Identifiable {
    let id = UUID()
    let type: InstructionType
    let distance: Double // meters to this point
    let coordinate: CLLocationCoordinate2D
    let text: String

    enum InstructionType {
        case straight, turnLeft, turnRight, sharpLeft, sharpRight
        case summit, waypoint, start, finish

        var icon: String {
            switch self {
            case .straight:   return "arrow.up"
            case .turnLeft:   return "arrow.turn.up.left"
            case .turnRight:  return "arrow.turn.up.right"
            case .sharpLeft:  return "arrow.turn.down.left"
            case .sharpRight: return "arrow.turn.down.right"
            case .summit:     return "mountain.2.fill"
            case .waypoint:   return "mappin.circle.fill"
            case .start:      return "figure.walk"
            case .finish:     return "flag.checkered"
            }
        }

        var color: Color {
            switch self {
            case .summit:  return .orange
            case .finish:  return .green
            case .start:   return .blue
            default:       return .primary
            }
        }
    }
}

@MainActor
class NavigationManager: ObservableObject {
    @Published var isNavigating = false
    @Published var instructions: [NavigationInstruction] = []
    @Published var currentInstructionIndex = 0
    @Published var distanceToNext: Double = 0
    @Published var totalRemainingDistance: Double = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var isOffRoute = false
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []

    @AppStorage("voiceGuidanceEnabled") var voiceGuidanceEnabled = true
    @AppStorage("voiceGuidanceVolume") var voiceGuidanceVolume: Double = 0.8

    private let synthesizer = AVSpeechSynthesizer()
    private let offRouteThreshold: Double = 50 // meters
    private let instructionTriggerDistance: Double = 30 // meters
    private var lastAnnouncedIndex = -1

    var currentInstruction: NavigationInstruction? {
        guard currentInstructionIndex < instructions.count else { return nil }
        return instructions[currentInstructionIndex]
    }

    var nextInstruction: NavigationInstruction? {
        let next = currentInstructionIndex + 1
        guard next < instructions.count else { return nil }
        return instructions[next]
    }

    var progress: Double {
        guard !instructions.isEmpty else { return 0 }
        return Double(currentInstructionIndex) / Double(instructions.count)
    }

    // MARK: - Start Navigation

    func startNavigation(coordinates: [CLLocationCoordinate2D], mountainName: String?) {
        guard coordinates.count >= 2 else { return }

        routeCoordinates = coordinates
        instructions = generateInstructions(from: coordinates, mountainName: mountainName)
        currentInstructionIndex = 0
        lastAnnouncedIndex = -1
        isNavigating = true
        isOffRoute = false

        calculateRemainingDistance(from: 0)

        if voiceGuidanceEnabled {
            announce("Navigation started. \(instructions.count) waypoints ahead.")
        }
    }

    func stopNavigation() {
        isNavigating = false
        instructions = []
        currentInstructionIndex = 0
        routeCoordinates = []
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Update with GPS

    func updateLocation(_ location: CLLocation) {
        guard isNavigating, !instructions.isEmpty else { return }

        // Check off-route
        let closestDistance = closestDistanceToRoute(from: location)
        isOffRoute = closestDistance > offRouteThreshold

        if isOffRoute && voiceGuidanceEnabled {
            announce("You are off route. Return to the trail.")
            return
        }

        // Check if we reached the current instruction point
        guard let current = currentInstruction else { return }
        let distToCurrent = location.distance(from: CLLocation(
            latitude: current.coordinate.latitude,
            longitude: current.coordinate.longitude
        ))

        distanceToNext = distToCurrent

        if distToCurrent < instructionTriggerDistance && currentInstructionIndex < instructions.count - 1 {
            currentInstructionIndex += 1
            calculateRemainingDistance(from: currentInstructionIndex)

            if voiceGuidanceEnabled && lastAnnouncedIndex != currentInstructionIndex {
                lastAnnouncedIndex = currentInstructionIndex
                if let next = currentInstruction {
                    announce(next.text)
                }
            }
        }

        // Check if we reached the final point
        if currentInstructionIndex == instructions.count - 1 && distToCurrent < instructionTriggerDistance {
            if voiceGuidanceEnabled {
                announce("You have arrived at your destination. Well done!")
            }
        }

        // Update ETA (avg hiking speed ~4 km/h)
        estimatedTimeRemaining = totalRemainingDistance / (4000.0 / 3600.0)
    }

    // MARK: - Voice Guidance

    func announce(_ text: String) {
        guard voiceGuidanceEnabled else { return }
        synthesizer.stopSpeaking(at: .word)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.volume = Float(voiceGuidanceVolume)
        synthesizer.speak(utterance)
    }

    // MARK: - Private

    private func generateInstructions(from coords: [CLLocationCoordinate2D], mountainName: String?) -> [NavigationInstruction] {
        var result: [NavigationInstruction] = []
        guard coords.count >= 2 else { return result }

        // Start
        result.append(NavigationInstruction(
            type: .start,
            distance: 0,
            coordinate: coords[0],
            text: "Start your hike. Head towards the trail."
        ))

        // Analyze route for turns
        var cumulativeDistance: Double = 0
        for i in 1..<coords.count {
            let prev = CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
            let curr = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let segmentDist = curr.distance(from: prev)
            cumulativeDistance += segmentDist

            // Detect significant turns (every ~200m or at real turns)
            if i >= 2 && i < coords.count - 1 {
                let bearing1 = bearing(from: coords[i-2], to: coords[i-1])
                let bearing2 = bearing(from: coords[i-1], to: coords[i])
                let angleDiff = normalizeAngle(bearing2 - bearing1)

                if abs(angleDiff) > 35 && cumulativeDistance > 100 {
                    let type: NavigationInstruction.InstructionType
                    let directionText: String

                    if angleDiff > 80 {
                        type = .sharpRight; directionText = "sharp right"
                    } else if angleDiff > 35 {
                        type = .turnRight; directionText = "right"
                    } else if angleDiff < -80 {
                        type = .sharpLeft; directionText = "sharp left"
                    } else {
                        type = .turnLeft; directionText = "left"
                    }

                    result.append(NavigationInstruction(
                        type: type,
                        distance: cumulativeDistance,
                        coordinate: coords[i],
                        text: "In \(Int(cumulativeDistance)) meters, turn \(directionText)."
                    ))
                    cumulativeDistance = 0
                }
            }

            // Every 500m add a straight instruction if no turn
            if cumulativeDistance > 500 && i < coords.count - 2 {
                result.append(NavigationInstruction(
                    type: .straight,
                    distance: cumulativeDistance,
                    coordinate: coords[i],
                    text: "Continue straight for \(Int(cumulativeDistance)) meters."
                ))
                cumulativeDistance = 0
            }
        }

        // Finish / Summit
        if let last = coords.last {
            result.append(NavigationInstruction(
                type: mountainName != nil ? .summit : .finish,
                distance: cumulativeDistance,
                coordinate: last,
                text: mountainName != nil ? "You're approaching \(mountainName!). Almost there!" : "You're approaching your destination."
            ))
        }

        return result
    }

    private func bearing(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        let lat1 = c1.latitude * .pi / 180
        let lat2 = c2.latitude * .pi / 180
        let dLon = (c2.longitude - c1.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var a = angle
        while a > 180 { a -= 360 }
        while a < -180 { a += 360 }
        return a
    }

    private func closestDistanceToRoute(from location: CLLocation) -> Double {
        var minDist = Double.greatestFiniteMagnitude
        for coord in routeCoordinates {
            let routePoint = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let dist = location.distance(from: routePoint)
            if dist < minDist { minDist = dist }
        }
        return minDist
    }

    private func calculateRemainingDistance(from index: Int) {
        var total: Double = 0
        for i in index..<routeCoordinates.count - 1 {
            let p1 = CLLocation(latitude: routeCoordinates[i].latitude, longitude: routeCoordinates[i].longitude)
            let p2 = CLLocation(latitude: routeCoordinates[i+1].latitude, longitude: routeCoordinates[i+1].longitude)
            total += p2.distance(from: p1)
        }
        totalRemainingDistance = total
    }
}

// MARK: - Navigation HUD View
struct NavigationHUDView: View {
    @ObservedObject var navManager: NavigationManager

    var body: some View {
        if navManager.isNavigating, let instruction = navManager.currentInstruction {
            VStack(spacing: 0) {
                // Off-route warning
                if navManager.isOffRoute {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Off Route - Return to trail")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.15))
                }

                HStack(spacing: 16) {
                    // Direction icon
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.accent.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: instruction.type.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(instruction.type.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(instruction.text)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Label(formatDistance(navManager.distanceToNext), systemImage: "location.fill")
                            Label(formatTime(navManager.estimatedTimeRemaining), systemImage: "clock.fill")
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Stop button
                    Button(action: { navManager.stopNavigation() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)

                // Progress bar
                GeometryReader { geo in
                    Rectangle()
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: geo.size.width * navManager.progress, height: 3)
                }
                .frame(height: 3)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) min"
    }
}
