import SwiftUI

// =========================================
// === DATEI: AscentApp.swift ===
// === Der Türsteher der App ===
// =========================================

@main
struct AscentApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("fitnessOnboardingCompleted") private var fitnessOnboardingCompleted = false
    @State private var showFitnessOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootShell {
                if isLoggedIn {
                    ContentView()
                        .environmentObject(appState)
                        .roundedFontDesign()
                        .onAppear {
                            appState.fetchProfileFromCloud()
                            // DEBUG: Uncomment once to re-show onboarding, then remove
                            fitnessOnboardingCompleted = false
                            if !fitnessOnboardingCompleted {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showFitnessOnboarding = true
                                }
                            }
                        }
                        .fullScreenCover(isPresented: $showFitnessOnboarding) {
                            FitnessOnboardingView {
                                showFitnessOnboarding = false
                            }
                            .roundedFontDesign()
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
