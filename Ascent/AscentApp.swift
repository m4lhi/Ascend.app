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
            RootShell {
                if isLoggedIn {
                    ContentView()
                        .environmentObject(appState)
                        .roundedFontDesign()
                        .onAppear {
                            appState.fetchProfileFromCloud()
                        }
                } else {
                    LoginView()
                        .environmentObject(appState)
                        .roundedFontDesign()
                }
            }
        }
    }
}
