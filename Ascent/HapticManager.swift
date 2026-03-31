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

    // Pre-allocated generators for lower latency
    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGen = UINotificationFeedbackGenerator()
    private let selectionGen = UISelectionFeedbackGenerator()

    // === Leichtes Feedback ===
    // Für: Button-Taps, kleine Interaktionen
    func light() {
        lightGen.impactOccurred()
    }

    // === Mittleres Feedback ===
    // Für: Wichtige Aktionen (z.B. Tour loggen)
    func medium() {
        mediumGen.impactOccurred()
    }

    // === Starkes Feedback ===
    // Für: Prestige-Events (sehr selten verwenden!)
    func heavy() {
        heavyGen.impactOccurred()
    }

    // === Erfolgs-Feedback ===
    // Für: Neues Level erreicht, Achievement freigeschaltet
    func success() {
        notificationGen.notificationOccurred(.success)
    }

    // === Fehler-Feedback ===
    // Für: Validierungsfehler, fehlgeschlagene Aktionen
    func error() {
        notificationGen.notificationOccurred(.error)
    }

    // === Selektion ===
    // Für: Picker-Wechsel, Tab-Wechsel
    func selection() {
        selectionGen.selectionChanged()
    }
}
