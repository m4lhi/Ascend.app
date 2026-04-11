import SwiftUI

// =========================================
// === DATEI: AnimatedLaunchView.swift ===
// === Branded splash with animated logo ===
// =========================================
//
// Shown for ~1.8s on cold launch. Hosts the real root view underneath
// and cross-fades out once the reveal animation completes.

struct RootShell<Root: View>: View {
    @ViewBuilder let root: () -> Root
    @State private var splashVisible = true

    var body: some View {
        ZStack {
            root()
                .opacity(splashVisible ? 0 : 1)

            if splashVisible {
                AnimatedLaunchView(onComplete: {
                    withAnimation(.easeOut(duration: 0.55)) {
                        splashVisible = false
                    }
                })
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}

struct AnimatedLaunchView: View {
    var onComplete: () -> Void = {}

    // Animation state
    @State private var bgOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.55
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -8
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 14
    @State private var wordmarkOpacity: Double = 0
    @State private var particlesOn: Bool = false
    @State private var shine: Bool = false

    var body: some View {
        ZStack {
            // === Background ===
            LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.75, blue: 1.00),
                    Color(red: 0.15, green: 0.50, blue: 1.00),
                    Color(red: 0.06, green: 0.33, blue: 0.80)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(bgOpacity)

            // Ambient light particles
            if particlesOn {
                LaunchParticlesLayer()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Soft radial bloom behind the logo
            RadialGradient(
                colors: [Color.white.opacity(0.28), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 220
            )
            .frame(width: 440, height: 440)
            .opacity(bgOpacity)
            .blur(radius: 30)

            VStack(spacing: 22) {
                ZStack {
                    // Expanding ring (like a shockwave)
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    Circle()
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                        .frame(width: 180, height: 180)
                        .scaleEffect(ringScale * 1.15)
                        .opacity(ringOpacity * 0.6)

                    // Logo card with shine
                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 146, height: 146)
                            .blur(radius: 0.6)

                        Image("AscentLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 130, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(0.28), radius: 30, y: 14)
                            .overlay(
                                // Diagonal shine sweep
                                GeometryReader { geo in
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.45), .clear],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                    .frame(width: geo.size.width * 0.6)
                                    .rotationEffect(.degrees(20))
                                    .offset(x: shine ? geo.size.width : -geo.size.width)
                                    .blendMode(.plusLighter)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            )
                            .scaleEffect(logoScale)
                            .rotationEffect(.degrees(logoRotation))
                            .opacity(logoOpacity)
                    }
                }

                VStack(spacing: 4) {
                    Text("ASCENT")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(8)
                    Text("Mountaineering, elevated.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))
                        .tracking(1.5)
                }
                .offset(y: wordmarkOffset)
                .opacity(wordmarkOpacity)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        // Background fades in
        withAnimation(.easeOut(duration: 0.45)) {
            bgOpacity = 1
        }

        // Logo pops in with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.68, dampingFraction: 0.62)) {
                logoScale = 1.0
                logoOpacity = 1
                logoRotation = 0
            }
            HapticManager.shared.light()
        }

        // Ring pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            ringOpacity = 0.9
            withAnimation(.easeOut(duration: 0.9)) {
                ringScale = 1.6
                ringOpacity = 0
            }
            particlesOn = true
        }

        // Shine sweep
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.9)) {
                shine = true
            }
        }

        // Wordmark slides up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                wordmarkOffset = 0
                wordmarkOpacity = 1
            }
        }

        // Exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            HapticManager.shared.light()
            onComplete()
        }
    }
}

// MARK: - Particles

private struct LaunchParticlesLayer: View {
    @State private var animate = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<16, id: \.self) { i in
                    let seed = Double(i)
                    let x = CGFloat((seed * 47).truncatingRemainder(dividingBy: Double(max(geo.size.width, 1))))
                    let delay = Double(i) * 0.07
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 3, height: 3)
                        .blur(radius: 0.3)
                        .position(x: x, y: animate ? -20 : geo.size.height + 20)
                        .animation(
                            .linear(duration: 5.5 + seed.truncatingRemainder(dividingBy: 3))
                                .repeatForever(autoreverses: false)
                                .delay(delay),
                            value: animate
                        )
                }
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    AnimatedLaunchView()
}
