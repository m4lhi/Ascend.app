import SwiftUI
import Supabase
import UserNotifications

// =========================================
// === DATEI: Settings.swift ===
// === Settings — Premium Dark Style ===
// =========================================

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("isLoggedIn") private var isLoggedIn = true
    
    @State private var showEditProfile = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var notificationDenied = false
    
    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)
    
    var body: some View {
        NavigationView {
            ZStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()
                
                // Ambient blobs (GPU-optimized)
                Circle()
                    .fill(RadialGradient(colors: [Color.blue.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: 125))
                    .frame(width: 250, height: 250)
                    .offset(x: -100, y: -100)
                Circle()
                    .fill(RadialGradient(colors: [Color.orange.opacity(0.06), Color.clear], center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 200)
                    .offset(x: 100, y: 300)
            }
            .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // === 1. PREFERENCES ===
                        SettingsSection(title: "PREFERENCES") {
                            Toggle(isOn: Binding(
                                get: { notificationsEnabled },
                                set: { newValue in
                                    if newValue {
                                        requestNotificationPermission()
                                    } else {
                                        notificationsEnabled = false
                                    }
                                }
                            )) {
                                SettingsRowLabel(icon: "bell.badge.fill", iconColor: .red, text: "Push Notifications")
                            }
                            .tint(gold)
                            
                            Divider().background(Color.black.opacity(0.1))
                            
                            Toggle(isOn: $isDarkMode) {
                                SettingsRowLabel(icon: "moon.fill", iconColor: .cyan, text: "Dark Mode")
                            }
                            .tint(gold)
                        }
                        
                        // === 2. ACCOUNT ===
                        SettingsSection(title: "ACCOUNT") {
                            Button(action: { showEditProfile = true }) {
                                SettingsRowLabel(icon: "person.crop.circle", iconColor: gold, text: "Edit Profile", showArrow: true)
                            }
                            
                            Divider().background(Color.black.opacity(0.1))
                            
                            Button(action: { showLogoutConfirm = true }) {
                                SettingsRowLabel(icon: "rectangle.portrait.and.arrow.right", iconColor: .orange, text: "Logout", showArrow: false)
                            }
                        }
                        
                        // === 3. ABOUT ===
                        SettingsSection(title: "ABOUT") {
                            Button(action: { showTerms = true }) {
                                SettingsRowLabel(icon: "doc.text.fill", iconColor: .gray, text: "Terms of Service", showArrow: true)
                            }
                            
                            Divider().background(Color.black.opacity(0.1))
                            
                            Button(action: { showPrivacy = true }) {
                                SettingsRowLabel(icon: "hand.raised.fill", iconColor: .gray, text: "Privacy Policy", showArrow: true)
                            }
                        }
                        
                        // === 4. DANGER ZONE ===
                        SettingsSection(title: "DANGER ZONE") {
                            Button(action: { showDeleteConfirm = true }) {
                                SettingsRowLabel(icon: "trash.fill", iconColor: .red, text: "Delete Account", textColor: .red)
                            }
                        }
                        
                        // Version info
                        VStack(spacing: 4) {
                            Text("Ascent")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Version 1.0.0 (Beta)")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Color(white: 0.98), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(.title3, design: .rounded))
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showEditProfile) {
            EditAccountView()
        }
        .sheet(isPresented: $showTerms) {
            SafariView(url: URL(string: "https://ascent.app/terms")!)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: URL(string: "https://ascent.app/privacy")!)
                .ignoresSafeArea()
        }
        .alert("Notification Access Denied", isPresented: $notificationDenied) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are disabled for Ascent. Please enable them in your device Settings to receive updates.")
        }
        .confirmationDialog("Logout", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Logout", role: .destructive) {
                performLogout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to logout? Your data is saved in the cloud.")
        }
        .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                // For now, just logout. Real deletion would need backend support.
                performLogout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
    }
    
    // === HELPERS ===
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationsEnabled = true
                } else {
                    notificationsEnabled = false
                    notificationDenied = true
                }
            }
        }
    }
    
    private func performLogout() {
        Task {
            do {
                try await supabase.auth.signOut()
            } catch {
                print("❌ Logout error: \(error.localizedDescription)")
            }
            await MainActor.run {
                isLoggedIn = false
                dismiss()
            }
        }
    }
}

// === Helper Views (kept from original) ===

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.gray)
                .tracking(2)
                .padding(.leading, 10)
            VStack(spacing: 15) { content }
                .padding(20)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        }
    }
}

struct SettingsRowLabel: View {
    let icon: String
    let iconColor: Color
    let text: String
    var textColor: Color = .primary
    var showArrow: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(textColor)
            Spacer()
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
    }
}
