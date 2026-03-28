//
//  HapticManager.swift
//  Ascent
//
//  Zentrale Verwaltung von haptischem Feedback.
//  Singleton-Muster: einmal erstellt, überall via HapticManager.shared nutzbar.
//  Feedback bleibt subtil — niemals aufdringlich.
//

import UIKit

// === Haptic Manager ===
final class HapticManager {

    // Singleton — verhindert mehrere Instanzen
    static let shared = HapticManager()
    private init() {}

    // === Leichtes Feedback ===
    // Für: Button-Taps, kleine Interaktionen
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // === Mittleres Feedback ===
    // Für: Wichtige Aktionen (z.B. Tour loggen)
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // === Starkes Feedback ===
    // Für: Prestige-Events (sehr selten verwenden!)
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    // === Erfolgs-Feedback ===
    // Für: Neues Level erreicht, Achievement freigeschaltet
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // === Fehler-Feedback ===
    // Für: Validierungsfehler, fehlgeschlagene Aktionen
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // === Selektion ===
    // Für: Picker-Wechsel, Tab-Wechsel
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
