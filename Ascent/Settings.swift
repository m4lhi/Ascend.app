import SwiftUI
import Supabase // WICHTIG: Damit die Settings mit der Cloud sprechen können

// =========================================
// === DATEI: SettingsView.swift ===
// === Einstellungen & Echter Logout ===
// =========================================

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Speichert Einstellungen lokal auf dem iPhone
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    // Unser UI-Türsteher
    @AppStorage("isLoggedIn") private var isLoggedIn = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        
                        // === 1. BEREICH: PREFERENCES ===
                        SettingsSection(title: "PREFERENCES") {
                            Toggle(isOn: $notificationsEnabled) {
                                SettingsRowLabel(icon: "bell.badge.fill", iconColor: .red, text: "Push Notifications")
                            }
                            .tint(Color(red: 0.85, green: 0.65, blue: 0.13))
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Toggle(isOn: $isDarkMode) {
                                SettingsRowLabel(icon: "moon.fill", iconColor: .cyan, text: "Dark Mode")
                            }
                            .tint(Color(red: 0.85, green: 0.65, blue: 0.13))
                        }
                        
                        // === 2. BEREICH: ACCOUNT ===
                        SettingsSection(title: "ACCOUNT") {
                            Button(action: { print("Edit Profile geklickt") }) {
                                SettingsRowLabel(icon: "person.crop.circle", iconColor: .gray, text: "Edit Profile", showArrow: true)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // === DER ECHTE SUPABASE LOGOUT BUTTON ===
                            Button(action: {
                                // Startet einen Hintergrund-Prozess für die Cloud
                                Task {
                                    do {
                                        // 1. Meldet dich offiziell bei Supabase ab
                                        try await supabase.auth.signOut()
                                        print("✅ Erfolgreich aus Supabase ausgeloggt!")
                                        
                                        // 2. Ändert die UI zurück zum Login-Screen
                                        await MainActor.run {
                                            isLoggedIn = false
                                            dismiss()
                                        }
                                    } catch {
                                        print("❌ Fehler beim Logout: \(error.localizedDescription)")
                                        
                                        // Falls es einen Fehler gibt, werfen wir dich trotzdem aus der App-Ansicht
                                        await MainActor.run {
                                            isLoggedIn = false
                                            dismiss()
                                        }
                                    }
                                }
                            }) {
                                SettingsRowLabel(icon: "rectangle.portrait.and.arrow.right", iconColor: .red, text: "Logout", textColor: .red)
                            }
                        }
                        
                        // === 3. BEREICH: LEGAL & ABOUT ===
                        SettingsSection(title: "ABOUT") {
                            Button(action: { print("AGB geklickt") }) {
                                SettingsRowLabel(icon: "doc.text.fill", iconColor: .gray, text: "Terms of Service (AGB)", showArrow: true)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Button(action: { print("Privacy geklickt") }) {
                                SettingsRowLabel(icon: "hand.raised.fill", iconColor: .gray, text: "Privacy Policy", showArrow: true)
                            }
                        }
                        
                        Text("Ascent Version 1.0.0 (Beta)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// === Hilfs-Views für das Design (Bleiben unverändert) ===
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).fontWeight(.bold).foregroundColor(.gray).tracking(1.5).padding(.leading, 10)
            VStack(spacing: 15) { content }
            .padding(20).background(Color(red: 0.12, green: 0.12, blue: 0.15)).cornerRadius(20)
        }
    }
}

struct SettingsRowLabel: View {
    let icon: String
    let iconColor: Color
    let text: String
    var textColor: Color = .white
    var showArrow: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.2)).frame(width: 32, height: 32)
                Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 14, weight: .bold))
            }
            Text(text).font(.subheadline).fontWeight(.semibold).foregroundColor(textColor)
            Spacer()
            if showArrow { Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray) }
        }
    }
}
