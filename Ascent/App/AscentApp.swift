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
    @StateObject private var leaderboardVM = LeaderboardViewModel()
    @StateObject private var discoveryVM = DiscoveryViewModel()
    @StateObject private var readinessVM = ReadinessViewModel()
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
                        .environmentObject(leaderboardVM)
                        .environmentObject(discoveryVM)
                        .environmentObject(readinessVM)
                        .roundedFontDesign()
                        .onAppear {
                            // ProfileVM owns the profile fetch (R3).
                            // After it resolves, apply XP/level onto AppState
                            // (transitional until R5/ProgressVM owns those)
                            // and kick off the post-profile init chain.
                            // FeedVM/LeaderboardVM are wired alongside;
                            // AppState retains weak refs so its still-owned
                            // tour-lifecycle + init chain can route through
                            // them. LeaderboardVM also holds weak refs to
                            // profileVM/feedVM/appState for its myProfile
                            // build and addFriend's chained refresh.
                            appState.profileVM = profileVM
                            appState.feedVM = feedVM
                            appState.leaderboardVM = leaderboardVM
                            appState.readinessVM = readinessVM
                            leaderboardVM.profileVM = profileVM
                            leaderboardVM.feedVM = feedVM
                            leaderboardVM.appState = appState
                            readinessVM.feedVM = feedVM
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
                        .environmentObject(leaderboardVM)
                        .environmentObject(discoveryVM)
                        .environmentObject(readinessVM)
                        .roundedFontDesign()
                }
            }
        }
    }
}
