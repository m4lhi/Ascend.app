import SwiftUI

// =========================================
// === DATEI: AscentApp.swift ===
// === Der Türsteher der App ===
// =========================================

@main
struct AscentApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var profileVM = ProfileViewModel()
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("fitnessOnboardingCompleted") private var fitnessOnboardingCompleted = false
    @State private var showFitnessOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootShell {
                if isLoggedIn {
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(profileVM)
                        .roundedFontDesign()
                        .onAppear {
                            // ProfileVM fetch runs in parallel with the
                            // existing AppState.fetchProfileFromCloud() — this
                            // is a temporary duplicate fetch, removed when the
                            // AppState wrapper is dropped in the cleanup commit.
                            Task { await profileVM.fetchProfile() }
                            appState.fetchProfileFromCloud()
                            // Route through HealthCoordinator (R2). Coordinator
                            // owns the 6h background analysis loop and is the
                            // sole writer into AppState.healthProfile/readiness.
                            HealthCoordinator.shared.attach(appState)
                            HealthCoordinator.shared.startBackgroundAnalysis()
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
                        .environmentObject(profileVM)
                        .roundedFontDesign()
                }
            }
        }
    }
}
