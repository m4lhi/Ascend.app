import SwiftUI

// =========================================
// === DATEI: SummitReadinessScreen.swift ===
// === Gentler-Streak-flavoured readiness detail screen ===
// =========================================
//
// Replaces SummitReadinessExtendedView's body-recovery half. The
// tour-risk questions (Nutrition, Environment, Logistics) are not
// here — they'll move to a separate tour-planning flow later. The
// old view stays in the repo untouched until the caller is switched.

struct SummitReadinessScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessVM: ReadinessViewModel

    var body: some View {
        ZStack {
            DesignSystem.Colors.paperWarm
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {

                    // Section 1 — placeholder for ReadinessScoreDisplay.
                    Color.clear.frame(height: 280)
                        .padding(.top, DesignSystem.Spacing.sm)

                    // Section 2 — What drives your score
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        sectionTitle("What drives your score")
                        Color.clear.frame(height: 220)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Section 3 — How do you feel?
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        sectionTitle("How do you feel?")
                        Color.clear.frame(height: 220)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Section 4 — Last 90 days
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        sectionTitle("Last 90 days")
                        Color.clear.frame(height: 180)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
        }
        .overlay(alignment: .topLeading) {
            closeButton
        }
    }

    // MARK: - Reusable bits

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.title2Inter)
            .foregroundStyle(DesignSystem.Colors.inkWarm)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(DesignSystem.Colors.inkWarm.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .padding(.leading, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
    }
}

#if DEBUG
#Preview("Light") {
    SummitReadinessScreen()
        .environmentObject(AppState())
        .environmentObject(ReadinessViewModel())
}

#Preview("Dark") {
    SummitReadinessScreen()
        .environmentObject(AppState())
        .environmentObject(ReadinessViewModel())
        .preferredColorScheme(.dark)
}
#endif
