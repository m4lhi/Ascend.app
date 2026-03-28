import SwiftUI

// =========================================
// === DATEI: AscentApp.swift ===
// === Der Türsteher der App ===
// =========================================

@main
struct AscentApp: App {
    // Unser App-Gehirn
    @StateObject private var appState = AppState()
    
    // @AppStorage merkt sich dauerhaft, ob wir eingeloggt sind.
    // Startwert ist "false" (nicht eingeloggt).
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            // Prüft, ob der User angemeldet ist
            if isLoggedIn {
                // JA: Zeige die normale App mit der Tab-Leiste
                ContentView()
                    .environmentObject(appState)
                    .onAppear {
                        appState.fetchProfileFromCloud()
                    }
                    } else {
                // NEIN: Zeige den neuen Login-Bildschirm
                LoginView()
                    .environmentObject(appState)
            }
        }
    }
}
