import SwiftUI
import Supabase // WICHTIG: Supabase hier importieren!
import AuthenticationServices

// =========================================
// === DATEI: LoginView.swift ===
// === Der echte Supabase Login ===
// =========================================

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    
    // === NEU: Für Lade-Animation und Fehlermeldungen ===
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            Circle()
                .fill(Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(y: -200)
            
            VStack(spacing: 25) {
                Spacer().frame(height: 30)
                
                // === LOGO & TITEL ===
                VStack(spacing: 10) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                        .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.5), radius: 10, y: 5)
                    
                    Text("ASCENT")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(4)
                    
                    Text(isRegistering ? "Join the Elite" : "Welcome back, Alpinist")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer().frame(height: 20)
                
                // === EINGABEFELDER ===
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "envelope.fill").foregroundColor(.gray)
                        TextField("Email Address", text: $email)
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never) // Wichtig für E-Mails!
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    HStack {
                        Image(systemName: "lock.fill").foregroundColor(.gray)
                        SecureField("Password", text: $password)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal, 30)
                
                // === NEU: FEHLERMELDUNG ANZEIGEN ===
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                // === DER ECHTE SUPABASE LOGIN BUTTON ===
                Button(action: {
                    // Startet die Authentifizierung
                    authenticateUser()
                }) {
                    ZStack {
                        if isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text(isRegistering ? "CREATE ACCOUNT" : "SIGN IN")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.85, green: 0.65, blue: 0.13))
                    .cornerRadius(12)
                    .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.4), radius: 10, y: 5)
                }
                .padding(.horizontal, 30)
                .disabled(isLoading || email.isEmpty || password.isEmpty) // Button sperren, wenn Felder leer sind
                .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                
                // === "ODER" TRENNLINIE ===
                HStack {
                    VStack { Divider().background(Color.gray.opacity(0.5)) }
                    Text("OR").font(.caption).foregroundColor(.gray).padding(.horizontal, 10)
                    VStack { Divider().background(Color.gray.opacity(0.5)) }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 5)
                
                // Apple Login (Für später geparkt, aktuell nur UI)
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in request.requestedScopes = [.fullName, .email] },
                    onCompletion: { result in print("Apple Login vorerst deaktiviert.") }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 55)
                .cornerRadius(12)
                .padding(.horizontal, 30)
                
                Spacer()
                
                // === WECHSEL ZWISCHEN LOGIN & REGISTRIERUNG ===
                Button(action: {
                    withAnimation(.easeInOut) {
                        isRegistering.toggle()
                        errorMessage = nil // Fehler beim Wechseln zurücksetzen
                    }
                }) {
                    HStack(spacing: 5) {
                        Text(isRegistering ? "Already have an account?" : "Don't have an account?")
                            .foregroundColor(.gray)
                        Text(isRegistering ? "Sign In" : "Register")
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                    }
                    .font(.subheadline)
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // =========================================
    // === DIE SUPABASE VERBINDUNGS-LOGIK ===
    // =========================================
    private func authenticateUser() {
        // Tastatur verstecken und Ladekreis anzeigen
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isLoading = true
        errorMessage = nil
        
        HapticManager.shared.medium()
        
        // Asynchroner Task für die Netzwerkabfrage
        Task {
            do {
                if isRegistering {
                    // 1. NEUEN ACCOUNT ERSTELLEN
                    // Greift auf die globale 'supabase' Variable zu!
                    _ = try await supabase.auth.signUp(email: email, password: password)
                    print("✅ Erfolgreich registriert!")
                } else {
                    // 2. BESTEHENDEN ACCOUNT EINLOGGEN
                    _ = try await supabase.auth.signIn(email: email, password: password)
                    print("✅ Erfolgreich eingeloggt!")
                }
                
                // Wenn kein Fehler geworfen wurde, loggen wir den User in der App ein!
                await MainActor.run {
                    isLoading = false
                    withAnimation(.spring()) {
                        isLoggedIn = true
                    }
                }
                
            } catch {
                // Wenn das Passwort falsch ist oder die E-Mail schon existiert
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    print("❌ Auth Fehler: \(error.localizedDescription)")
                }
            }
        }
    }
}
