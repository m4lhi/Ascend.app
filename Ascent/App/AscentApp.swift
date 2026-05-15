import SwiftUI

// =========================================
// === DATEI: AscentApp.swift ===
// === Der Türsteher der App ===
// =========================================

@main
struct AscentApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var profileVM = ProfileViewModel()
    @StateObject private var feedVM = FeedViewModel()
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
                        .environmentObject(feedVM)
                        .roundedFontDesign()
                        .onAppear {
                            // ProfileVM owns the profile fetch (R3).
                            // After it resolves, apply XP/level onto AppState
                            // (transitional until R5/ProgressVM owns those)
                            // and kick off the post-profile init chain.
                            // FeedVM is wired alongside; AppState retains a
                            // weak ref so its still-owned tour-lifecycle
                            // methods can mutate the feed cache.
                            appState.profileVM = profileVM
                            appState.feedVM = feedVM
                            Task {
                                await profileVM.fetchProfile()
                                if let p = profileVM.lastFetchedProfile {
                                    appState.currentXP = p.xp
                                    appState.currentLevel = p.level
                                }
                                appState.fetchInitialDataChain()
                            }
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
                        .environmentObject(feedVM)
                        .roundedFontDesign()
                }
            }
        }
    }
}
