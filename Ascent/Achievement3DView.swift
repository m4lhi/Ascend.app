import SwiftUI
import SplineRuntime

// =========================================
// === DATEI: Achievement3DView.swift ===
// === Native Spline 3D Integration ===
// =========================================

struct Achievement3DView: View {
    let iconName: String
    let badgeColor: Color
    let isUnlocked: Bool

    // Hier ist der Lade-Link für die Spline-Szene
    let splineURLString = "https://prod.spline.design/lupzoMgUb7kFKq8M/scene.splinecode"

    var body: some View {
        ZStack {
            if let url = URL(string: splineURLString) {
                // Hier wird Splines nativer Swift-Renderer verwendet (nutzt Metal statt WebGL)
                SplineView(sceneFileURL: url)
                    .ignoresSafeArea(.all)
            } else {
                ProgressView()
                    .tint(.gray)
            }
        }
        // Optional: Ausgrauen, falls Badge noch gelockt ist
        .opacity(isUnlocked ? 1.0 : 0.4)
        .saturation(isUnlocked ? 1.0 : 0.0)
    }
}

