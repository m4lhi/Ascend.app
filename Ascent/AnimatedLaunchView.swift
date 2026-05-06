import SwiftUI

// =========================================
// === DATEI: AnimatedLaunchView.swift ===
// === Pass-through RootShell ===
// =========================================
//
// Splash screen has been removed. RootShell now mounts the real root view
// directly. The previous animated logo / particles / shockwave effect has
// been retired in favor of going straight into content.

struct RootShell<Root: View>: View {
    @ViewBuilder let root: () -> Root

    var body: some View {
        root()
    }
}
