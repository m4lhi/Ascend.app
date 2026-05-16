import SwiftUI
import UIKit

// =========================================
// === DATEI: SummitReadinessScreen.swift ===
// === Gentler-Streak-flavoured readiness detail screen ===
// =========================================
//
// Replaces SummitReadinessExtendedView's body-recovery half. The
// tour-risk questions (Nutrition, Environment, Logistics) are not
// here — they'll move to a separate tour-planning flow later. The
// old view stays in the repo untouched until the caller is switched.

enum CheckInVariant {
    case quick
    case detailed
}

struct SummitReadinessScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessVM: ReadinessViewModel
    @EnvironmentObject var feedVM: FeedViewModel

    @State private var userOverrideVariant: CheckInVariant? = nil
    @State private var selectedMood: String? = nil
    @State private var detailAnswers: [String: String] = [:]

    var body: some View {
        ZStack {
            DesignSystem.Colors.paperWarm
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {

                    // Section 1 — large topographic score display.
                    ReadinessScoreDisplay(
                        score: readinessVM.readiness?.totalScore ?? 0,
                        status: readinessVM.readiness?.status ?? "No assessment yet"
                    )
                    .padding(.top, DesignSystem.Spacing.sm)

                    // Section 2 — What drives your score
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        sectionTitle("What drives your score")
                        bentoBreakdown
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Section 3 — Daily check-in (adaptive quick/detailed)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        sectionTitle("How do you feel?")
                        checkInSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Section 4 — 30-day trend + stat pills
                    ReadinessTrendDisplay(history: readinessVM.readinessHistory)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
        }
        .overlay(alignment: .topLeading) {
            closeButton
        }
        .onAppear(perform: restoreCheckInState)
    }

    /// Hydrate the section-3 selection from the persisted answers so the
    /// user sees their previous picks highlighted on reopen.
    private func restoreCheckInState() {
        let saved = readinessVM.extendedReadinessAnswers
        if let overall = saved["overall"]?.first {
            selectedMood = overall
        }
        detailAnswers = saved
            .filter { $0.key != "overall" }
            .reduce(into: [:]) { acc, pair in
                if let first = pair.value.first { acc[pair.key] = first }
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

    // MARK: - Section 2: Bento breakdown

    private var bentoBreakdown: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                recoveryCard
                trainingLoadCard
            }
            acclimatizationCard
        }
    }

    private var recoveryCard: some View {
        let profile = readinessVM.healthProfile

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 6) {
                ReadinessGlyph()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(DesignSystem.Colors.inkOnSage.opacity(0.78))
                Text("Recovery")
                    .font(DesignSystem.Typography.kickerInter)
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.Colors.inkOnSage.opacity(0.62))
            }

            if let hrv = profile?.heartRateVariability {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(hrv.rounded()))")
                        .font(.custom("Inter", size: 28).weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.inkOnSage)
                        .monospacedDigit()
                    Text("ms")
                        .font(DesignSystem.Typography.footnoteInter)
                        .foregroundStyle(DesignSystem.Colors.inkOnSage.opacity(0.55))
                }
                Text("HRV")
                    .font(DesignSystem.Typography.footnoteInter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSage.opacity(0.55))
            } else {
                Text("Connect Apple Health")
                    .font(DesignSystem.Typography.footnoteInter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSage.opacity(0.55))
                    .padding(.vertical, 6)
            }

            // Sub-stats: sleep + RHR
            VStack(alignment: .leading, spacing: 3) {
                if let mins = profile?.sleepMinutesLastNight, mins > 0 {
                    statRow(label: "Sleep", value: formatSleep(mins))
                }
                if let rhr = profile?.restingHeartRate {
                    statRow(label: "Resting HR", value: "\(rhr) bpm")
                }
            }

            // TODO: 7-day HRV trend sparkline once history is exposed by HealthKitBridge.
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .pastelCard(.sage, applyForeground: false)
    }

    private var trainingLoadCard: some View {
        let (statusWord, deltaText) = trainingLoadInsights
        let isOverreach = statusWord == "Overreaching"

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 6) {
                ActivityGlyph()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(DesignSystem.Colors.inkOnIce.opacity(0.78))
                Text("Training Load")
                    .font(DesignSystem.Typography.kickerInter)
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.Colors.inkOnIce.opacity(0.62))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(statusWord)
                    .font(.custom("Inter", size: 22).weight(.semibold))
                    .foregroundStyle(isOverreach ? DesignSystem.Colors.ember : DesignSystem.Colors.inkOnIce)

                if isOverreach {
                    Circle()
                        .fill(DesignSystem.Colors.ember)
                        .frame(width: 6, height: 6)
                        .offset(y: -8)
                }
            }

            Text(deltaText)
                .font(DesignSystem.Typography.footnoteInter)
                .foregroundStyle(DesignSystem.Colors.inkOnIce.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .pastelCard(.ice, applyForeground: false)
    }

    private var acclimatizationCard: some View {
        let info = acclimatizationInfo

        return HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            ElevationGlyph()
                .frame(width: 22, height: 22)
                .foregroundStyle(info.recent
                                 ? DesignSystem.Colors.meadow
                                 : DesignSystem.Colors.inkOnSand.opacity(0.55))

            VStack(alignment: .leading, spacing: 3) {
                Text("Acclimatization")
                    .font(DesignSystem.Typography.kickerInter)
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand.opacity(0.62))
                Text(info.text)
                    .font(DesignSystem.Typography.bodyEmphasisInter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pastelCard(.sand, applyForeground: false)
    }

    // MARK: - Section 2 helpers

    private func statRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(DesignSystem.Typography.footnoteInter)
                .foregroundStyle(DesignSystem.Colors.inkOnSage.opacity(0.55))
            Spacer(minLength: 0)
            Text(value)
                .font(DesignSystem.Typography.footnoteInter.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.inkOnSage.opacity(0.82))
                .monospacedDigit()
        }
    }

    private func formatSleep(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)min"
    }

    /// (statusWord, deltaText) derived from the same ACWR math as
    /// ReadinessManager so the card aligns with the score it explains.
    /// Falls back to "Neutral" when chronic load is too thin to compute.
    private var trainingLoadInsights: (String, String) {
        let now = Date()
        let cal = Calendar.current
        let tours = feedVM.recentTours

        let last7 = tours.filter { (cal.dateComponents([.day], from: $0.date, to: now).day ?? 100) <= 7 }
        let last28 = tours.filter { (cal.dateComponents([.day], from: $0.date, to: now).day ?? 100) <= 28 }

        let acute = last7.reduce(0) { $0 + Double($1.elevationGainMeters) }
        let chronic = last28.reduce(0) { $0 + Double($1.elevationGainMeters) } / 4.0

        guard chronic >= 100 else {
            return ("Building", "Not enough recent activity to gauge load")
        }

        let ratio = acute / max(chronic, 1)
        let pct = Int(((ratio - 1.0) * 100).rounded())

        if ratio > 1.3 {
            return ("Overreaching", "Acute load \(pct >= 0 ? "+\(pct)" : "\(pct)")% over average. Ease back.")
        } else if ratio < 0.8 {
            return ("Detraining", "Acute load \(pct)% below average. Volume is fading.")
        } else {
            return ("Optimal", "Steady progression (ratio \(String(format: "%.1f", ratio)))")
        }
    }

    /// "Last >2000m: N days ago" when there is a recent qualifying tour
    /// within 30 days, otherwise "No recent altitude exposure".
    private var acclimatizationInfo: (text: String, recent: Bool) {
        let tours = feedVM.recentTours.filter { $0.elevationGainMeters > 2000 }
        guard let mostRecent = tours.max(by: { $0.date < $1.date }) else {
            return ("No recent altitude exposure", false)
        }
        let days = Calendar.current.dateComponents([.day], from: mostRecent.date, to: Date()).day ?? 99
        if days > 30 {
            return ("No recent altitude exposure", false)
        }
        if days == 0 { return ("Last >2000m: today", true) }
        if days == 1 { return ("Last >2000m: yesterday", true) }
        return ("Last >2000m: \(days) days ago", true)
    }

    // MARK: - Section 3: Daily check-in

    private var activeVariant: CheckInVariant {
        userOverrideVariant ?? detectedVariant
    }

    /// HRV + Sleep + RHR coverage from the HealthKit profile. ≥2
    /// signals available → the quick variant covers it. Otherwise
    /// fall back to the 5-question detailed flow.
    private var detectedVariant: CheckInVariant {
        let p = readinessVM.healthProfile
        let hasHRV = p?.heartRateVariability != nil
        let hasSleep = (p?.sleepMinutesLastNight ?? 0) > 0
        let hasRHR = p?.restingHeartRate != nil
        let coverage = [hasHRV, hasSleep, hasRHR].filter { $0 }.count
        return coverage >= 2 ? .quick : .detailed
    }

    @ViewBuilder
    private var checkInSection: some View {
        switch activeVariant {
        case .quick:    quickCheckIn
        case .detailed: detailedCheckIn
        }
    }

    private var quickCheckIn: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            let moods = ["Strong", "Okay", "Tired", "Drained"]
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DesignSystem.Spacing.sm),
                          GridItem(.flexible(), spacing: DesignSystem.Spacing.sm)],
                spacing: DesignSystem.Spacing.sm
            ) {
                ForEach(moods, id: \.self) { mood in
                    CheckInCard(
                        title: mood,
                        isSelected: selectedMood == mood,
                        onTap: { pickMood(mood) }
                    )
                }
            }

            variantToggle(to: .detailed, label: "Switch to detailed check ↓")
        }
    }

    private var detailedCheckIn: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            detailQuestion(id: "sleep",  prompt: "Sleep",        options: ["Restored", "Okay", "Light", "Barely slept"])
            detailQuestion(id: "energy", prompt: "Energy",       options: ["Strong", "Okay", "Low", "Drained"])
            detailQuestion(id: "legs",   prompt: "Legs",         options: ["Fresh", "Okay", "Sore", "Heavy"])
            detailQuestion(id: "focus",  prompt: "Mental focus", options: ["Sharp", "Okay", "Foggy", "Scattered"])
            detailQuestion(id: "hr",     prompt: "Resting HR feel", options: ["Calm", "Normal", "Elevated"])

            submitDetailButton

            variantToggle(to: .quick, label: "Switch to quick check ↑")
        }
    }

    private var submitDetailButton: some View {
        Button(action: submitDetail) {
            Text("Save check-in")
                .font(DesignSystem.Typography.bodyEmphasisInter)
                .foregroundStyle(DesignSystem.Colors.paperWarm)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                        .fill(detailAnswers.isEmpty
                              ? DesignSystem.Colors.inkWarm.opacity(0.25)
                              : DesignSystem.Colors.glacierDeep)
                )
        }
        .buttonStyle(.plain)
        .disabled(detailAnswers.isEmpty)
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private func detailQuestion(id: String, prompt: String, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(prompt)
                .font(DesignSystem.Typography.bodyEmphasisInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)

            // Wrap options in a HStack — narrow enough on phone for 4
            // cards in a row; the 3-card "hr" row stays the same.
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(options, id: \.self) { option in
                    CheckInCard(
                        title: option,
                        isSelected: detailAnswers[id] == option,
                        onTap: { pickDetail(id: id, option: option) }
                    )
                }
            }
        }
    }

    private func variantToggle(to target: CheckInVariant, label: String) -> some View {
        Button {
            withAnimation(DesignSystem.Animations.standard) {
                userOverrideVariant = target
            }
        } label: {
            Text(label)
                .font(DesignSystem.Typography.footnoteInter)
                .foregroundStyle(DesignSystem.Colors.glacierDeep)
        }
        .buttonStyle(.plain)
        .padding(.top, DesignSystem.Spacing.xs)
    }

    /// Quick variant: save + refresh + haptic on every tap. The score
    /// updates instantly because there's only one answer to commit.
    private func pickMood(_ mood: String) {
        selectedMood = mood
        readinessVM.extendedReadinessAnswers = ["overall": [mood]]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        finishCheckIn()
    }

    /// Detail variant: accumulate the pick in local state only. The
    /// score commit waits for the user to hit Save — otherwise it
    /// would bounce 5 times while they fill the form.
    private func pickDetail(id: String, option: String) {
        detailAnswers[id] = option
    }

    /// Detail variant submit: write all five answers in one shot,
    /// then refresh + history. Haptic on success.
    private func submitDetail() {
        readinessVM.extendedReadinessAnswers = detailAnswers.mapValues { [$0] }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        finishCheckIn()
    }

    /// Mark answered, recompute the readiness score from HealthKit +
    /// tours + check-in answers, and append today's composite score
    /// to the 90-day history.
    private func finishCheckIn() {
        readinessVM.extendedReadinessAnsweredAt = Date()
        readinessVM.refresh()
        readinessVM.recordReadinessScore(readinessVM.timeToGoScore)
    }
}

// MARK: - CheckInCard (mood option button)

fileprivate struct CheckInCard: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(DesignSystem.Typography.bodyEmphasisInter)
                .foregroundStyle(isSelected
                                 ? DesignSystem.Colors.inkWarm
                                 : DesignSystem.Colors.inkWarm.opacity(0.62))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                        .fill(isSelected ? DesignSystem.Colors.sageCard : DesignSystem.Colors.paperWarm)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                        .stroke(
                            isSelected ? DesignSystem.Colors.glacierDeep : DesignSystem.Colors.borderSubtle,
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
                .animation(DesignSystem.Animations.quick, value: isSelected)
        }
        .buttonStyle(.plain)
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
