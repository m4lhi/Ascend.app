import SwiftUI
import Supabase
import AuthenticationServices

// =========================================
// === DATEI: LoginView.swift ===
// === Premium minimal sign-in ===
// =========================================

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    var body: some View {
        ZStack {
            // Solid surface — no gradient noise
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // One soft accent halo behind the logo. Subtle, premium.
            Circle()
                .fill(DesignSystem.Colors.accent.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 80)
                .offset(y: -260)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    // === Logo / Brand ===
                    VStack(spacing: 14) {
                        Image("AscentLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: DesignSystem.Colors.accent.opacity(0.18), radius: 24, y: 12)

                        VStack(spacing: 6) {
                            Text("ASCENT")
                                .font(.app(size: 30, weight: .black))
                                .foregroundColor(.primary)
                                .tracking(4)

                            Text(isRegistering
                                 ? "Build your alpine identity."
                                 : "Welcome back. Your peaks await.")
                                .font(.app(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer().frame(height: 48)

                    // === Form ===
                    VStack(spacing: 14) {
                        inputField(
                            icon: "envelope",
                            placeholder: "Email",
                            text: $email,
                            isSecure: false,
                            keyboard: .emailAddress,
                            field: .email
                        )

                        inputField(
                            icon: "lock",
                            placeholder: "Password",
                            text: $password,
                            isSecure: true,
                            keyboard: .default,
                            field: .password
                        )

                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(errorMessage)
                                    .font(.app(size: 13, weight: .medium))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .foregroundColor(DesignSystem.Colors.error)
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 24)

                    // === Primary action ===
                    Button(action: authenticateUser) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isRegistering ? "Create account" : "Sign in")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.55 : 1.0)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 28)

                    // === Divider ===
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(DesignSystem.Colors.cardBorder)
                            .frame(height: 0.5)
                        Text("OR")
                            .font(.app(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.4)
                        Rectangle()
                            .fill(DesignSystem.Colors.cardBorder)
                            .frame(height: 0.5)
                    }
                    .padding(.horizontal, 36)

                    Spacer().frame(height: 24)

                    // === Apple Sign-In (UI only for now) ===
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in request.requestedScopes = [.fullName, .email] },
                        onCompletion: { _ in print("Apple Login coming soon.") }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.full, style: .continuous))
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)

                    // === Toggle Sign-In / Register ===
                    Button {
                        withAnimation(DesignSystem.Animations.standard) {
                            isRegistering.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(isRegistering ? "Already a member?" : "New to Ascent?")
                                .foregroundColor(.secondary)
                            Text(isRegistering ? "Sign in" : "Create account")
                                .foregroundColor(DesignSystem.Colors.accent)
                                .fontWeight(.bold)
                        }
                        .font(.app(size: 14, weight: .medium))
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .animation(DesignSystem.Animations.standard, value: errorMessage)
    }

    // MARK: - Input field
    @ViewBuilder
    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        keyboard: UIKeyboardType,
        field: Field
    ) -> some View {
        let isFocused = focusedField == field

        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? DesignSystem.Colors.accent : .secondary)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.app(size: 16, weight: .regular))
            .foregroundColor(.primary)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(
                    isFocused ? DesignSystem.Colors.accent.opacity(0.55) : DesignSystem.Colors.cardBorder,
                    lineWidth: isFocused ? 1.5 : 0.75
                )
        )
        .animation(DesignSystem.Animations.quick, value: isFocused)
    }

    // =========================================
    // === SUPABASE AUTH ===
    // =========================================
    private func authenticateUser() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isLoading = true
        errorMessage = nil

        HapticManager.shared.medium()

        Task {
            do {
                if isRegistering {
                    _ = try await supabase.auth.signUp(email: email, password: password)
                } else {
                    _ = try await supabase.auth.signIn(email: email, password: password)
                }

                await MainActor.run {
                    isLoading = false
                    withAnimation(.spring()) {
                        isLoggedIn = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    print("Auth error: \(error.localizedDescription)")
                }
            }
        }
    }
}
