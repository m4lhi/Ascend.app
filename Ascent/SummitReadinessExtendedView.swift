import SwiftUI

// =========================================
// === DATEI: SummitReadinessExtendedView.swift ===
// === 20-question Summit Readiness assessment ===
// =========================================
//
// Replaces the 5-slider "ReadinessQuestionnaireView" as the tap-target for
// the Summit Readiness widget. Structure:
//
//   • 5 mandatory sliders / pickers (sleep, soreness, joints, motivation, HR)
//   • 15 extended questions across Nutrition, Mental, Environment, Logistics
//   • Tips per question (small "i" button that reveals expert context)
//   • Skip-at-own-risk button → logs an empty assessment but flags warning

struct SummitReadinessExtendedView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // Mandatory (1–5)
    @State private var sleepQuality: Double = 3
    @State private var muscleSoreness: Double = 3
    @State private var jointPain: Double = 1
    @State private var mentalMotivation: Double = 3
    @State private var perceivedHR: Double = 3

    // Extended answers — stored by question id so we can persist them.
    @State private var answers: [String: [String]] = [:]

    @State private var showTipFor: String? = nil
    @State private var showSkipWarning = false
    @State private var barProgress: Double = 0
    @State private var barSquished: Bool = false

    private let accent = DesignSystem.Colors.accent

    private var readinessScore: Int { appState.timeToGoScore }

    private var barColor: Color {
        switch readinessScore {
        case ..<35: return Color(red: 1.0, green: 0.23, blue: 0.19)
        case ..<60: return Color(red: 1.0, green: 0.58, blue: 0.0)
        case ..<80: return Color(red: 0.65, green: 0.84, blue: 0.0)
        default:    return Color(red: 0.20, green: 0.78, blue: 0.35)
        }
    }

    private var statusLabel: String {
        switch readinessScore {
        case ..<35: return "NOT READY"
        case ..<60: return "GETTING THERE"
        case ..<80: return "ALMOST READY"
        default:    return "SUMMIT READY"
        }
    }

    // Mandatory question metadata kept alongside the sliders — the ids are
    // what we write back into `appState.extendedReadinessAnswers` on save.
    private let mandatoryIds = ["sleep", "soreness", "joints", "motivation", "hr"]

    private let sections: [ReadinessSection] = [
        .init(title: "Nutrition & Fuel", icon: "fork.knife", items: [
            .init(id: "hydration", prompt: "Hydration over last 24h", options: ["Excellent (>3L)", "Adequate (2-3L)", "Low (<2L)", "Dehydrated"], tip: "Dehydration >2% bodyweight halves aerobic capacity at altitude."),
            .init(id: "lastMeal", prompt: "When did you last eat?", options: ["<1h ago", "1-3h ago", "3-6h ago", ">6h ago"], tip: "Below 3000 kcal/day of intake in preparation weeks risks glycogen depletion on summit day."),
            .init(id: "caffeine", prompt: "Caffeine today (mg est.)", options: ["None", "<100", "100-300", ">300"], tip: "Caffeine >400mg shortens REM sleep — compounding fatigue for back-to-back days."),
            .init(id: "alcohol", prompt: "Alcohol in last 48h?", options: ["None", "1-2 drinks", "3-5 drinks", ">5 drinks"], tip: "Alcohol reduces VO₂ max up to 72h after consumption — avoid before technical ascents.")
        ]),
        .init(title: "Mental & Focus", icon: "brain.head.profile", items: [
            .init(id: "stress", prompt: "Life stress level right now", options: ["Very low", "Manageable", "High", "Overwhelming"], tip: "High-stress days correlate with ×2.3 decision errors on exposed terrain."),
            .init(id: "focus", prompt: "Can you focus 30min without phone?", options: ["Easily", "With effort", "Struggling", "No"], tip: "Poor sustained focus is a leading indicator of rope-handling errors."),
            .init(id: "anxiety", prompt: "Pre-climb anxiety", options: ["Calm", "Normal nerves", "Elevated", "Dread"], tip: "Elevated anxiety pre-climb is a strong abort signal — trust it."),
            .init(id: "confidence", prompt: "Confidence in the objective", options: ["Very high", "Solid", "Shaky", "Low"], tip: "Confidence gap on a route you know well signals under-trained conditioning.")
        ]),
        .init(title: "Environment & Gear", icon: "backpack.fill", items: [
            .init(id: "temperature", prompt: "Expected temp at summit", options: ["> 0°C", "-10 to 0°C", "-20 to -10°C", "< -20°C"], tip: "Below -15°C expose-time thresholds drop below 2min — gear must match."),
            .init(id: "weatherWindow", prompt: "Weather window length", options: ["> 48h stable", "24-48h", "12-24h", "< 12h"], tip: "Windows under 18h require pre-committed turnaround times."),
            .init(id: "avalanche", prompt: "Avalanche risk at route", options: ["Low (1)", "Moderate (2)", "Considerable (3)", "High (4)+"], tip: "Most alpine fatalities occur at rating 3 — the deceptive middle."),
            .init(id: "daylight", prompt: "Usable daylight for objective", options: ["Abundant", "Tight but safe", "Marginal", "Committing headlamp"], tip: "Plan with 90min daylight buffer — descents are ×2 slower than ascents when tired.")
        ]),
        .init(title: "Logistics & Team", icon: "person.2.fill", items: [
            .init(id: "partners", prompt: "Partner readiness", options: ["Strong & rested", "Matched", "Slower than me", "Solo / unsure"], tip: "The weakest partner sets the risk ceiling — not the ego ceiling."),
            .init(id: "gear", prompt: "Gear check completed?", options: ["Full check done", "Partial", "Packed in rush", "Unsure"], tip: "60% of epics start with one forgotten item — always double-pack critical redundancy."),
            .init(id: "escape", prompt: "Escape routes identified?", options: ["≥2 options", "One option", "Unclear", "None"], tip: "If you can't name your turnaround points before starting, you will not find them under fatigue.")
        ])
    ]

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                // Animated gradient wash — starts at width 0, sweeps right with bar
                GeometryReader { geo in
                    LinearGradient(
                        colors: [barColor.opacity(0.55), barColor.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width * barProgress, height: 320)
                    .ignoresSafeArea(edges: .top)
                    .animation(.spring(response: 1.1, dampingFraction: 0.78).delay(0.25), value: barProgress)
                }
                .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 22) {
                        header
                        mandatorySection
                        ForEach(sections) { section in
                            extendedSection(section)
                        }
                        saveSection
                    }
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
            .background(.clear)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") { showSkipWarning = true }
                        .foregroundColor(.orange)
                }
            }
            .alert("Skip at your own risk", isPresented: $showSkipWarning) {
                Button("Skip anyway", role: .destructive) { saveSkipped() }
                Button("Continue assessment", role: .cancel) { }
            } message: {
                Text("Skipping means no subjective readiness factors feed into your Time-to-Go score. We strongly recommend answering the 5 essential questions — they take under 60 seconds.")
            }
            .background(.clear)
            .onAppear {
                answers = appState.extendedReadinessAnswers
                for (id, defaultVal) in [("sleep", sleepQuality), ("soreness", muscleSoreness),
                                          ("joints", jointPain), ("motivation", mentalMotivation),
                                          ("hr", perceivedHR)] {
                    if answers[id] == nil {
                        answers[id] = [String(Int(defaultVal))]
                    }
                }
                // Fill bar animates in
                withAnimation(.spring(response: 1.1, dampingFraction: 0.78).delay(0.3)) {
                    barProgress = Double(readinessScore) / 100.0
                }
                // Squeeze fires when fill lands
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                        barSquished = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.52)) {
                            barSquished = false
                        }
                    }
                }
            }
        }
        .background(.clear)
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 0) {
            // Small label row above the bar
            HStack {
                Text("SUMMIT READINESS")
                    .font(.appMono(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.8)
                Spacer()
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(barColor)
                    .animation(.easeOut(duration: 0.4), value: barColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 12)

            // THE BAR — edge-to-edge, height = number size
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Empty track — neutral, no color tint
                    Rectangle()
                        .fill(Color(UIColor.systemFill))

                    // Animated color fill from the left
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geo.size.width * barProgress)
                        .animation(.spring(response: 1.1, dampingFraction: 0.78).delay(0.25), value: barProgress)

                    // Percentage number lives INSIDE the bar
                    Text("\(readinessScore)%")
                        .font(.appMono(size: 44, weight: .black))
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                }
            }
            .frame(height: 72)
            .scaleEffect(x: 1.0, y: barSquished ? 0.48 : 1.0, anchor: .center)

            // Status label + progress info below bar
            HStack(spacing: 6) {
                Text(statusLabel)
                    .font(.appMono(size: 10, weight: .bold))
                    .foregroundColor(barColor)
                    .tracking(1.3)
                    .animation(.easeOut(duration: 0.3), value: statusLabel)
                Spacer()
                Circle().fill(Color.orange).frame(width: 5, height: 5)
                Text("\(mandatoryAnsweredCount)/5 essential answered")
                    .font(.appMono(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
    }

    private var mandatorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Essential (required)", icon: "star.fill", color: .orange)

            mandatorySlider(id: "sleep", title: "Sleep quality", value: $sleepQuality, icon: "bed.double.fill",
                            minLabel: "Exhausted", maxLabel: "Fully restored",
                            tip: "Sleep <6h trebles altitude headache risk.")

            mandatorySlider(id: "soreness", title: "Muscle soreness", value: $muscleSoreness, icon: "figure.run",
                            minLabel: "Heavy", maxLabel: "Fresh",
                            tip: "DOMS >72h indicates overreach — delay technical objectives.")

            mandatorySlider(id: "joints", title: "Joint / tendon pain", value: $jointPain, icon: "bolt.heart.fill",
                            minLabel: "None", maxLabel: "Acute",
                            tip: "Joint pain is the #1 silent summit-day failure. Don't ignore.", reverse: true)

            mandatorySlider(id: "motivation", title: "Mental motivation", value: $mentalMotivation, icon: "brain.head.profile",
                            minLabel: "Flat", maxLabel: "Laser focused",
                            tip: "Low motivation with high-stakes objective → abort calibration required.")

            mandatorySlider(id: "hr", title: "Resting HR feel", value: $perceivedHR, icon: "heart.fill",
                            minLabel: "Racing", maxLabel: "Calm",
                            tip: "RHR >7bpm above baseline for 2 days = probable under-recovery.")
        }
        .padding(.horizontal, 16)
    }

    private func extendedSection(_ section: ReadinessSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: section.title, icon: section.icon, color: accent)
            VStack(spacing: 10) {
                ForEach(section.items) { item in
                    questionCard(item)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func questionCard(_ item: ReadinessQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.prompt)
                    .font(.app(size: 14, weight: .bold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        showTipFor = showTipFor == item.id ? nil : item.id
                    }
                } label: {
                    Image(systemName: showTipFor == item.id ? "info.circle.fill" : "info.circle")
                        .font(.app(size: 15))
                        .foregroundColor(accent)
                }
            }

            if showTipFor == item.id {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.app(size: 11))
                        .foregroundColor(.orange)
                    Text(item.tip)
                        .font(.app(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            FlowOptions(options: item.options, selected: answers[item.id]?.first) { picked in
                answers[item.id] = [picked]
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var saveSection: some View {
        VStack(spacing: 12) {
            Button(action: save) {
                Text("Save Assessment")
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(mandatoryAnsweredCount < 5)
            .opacity(mandatoryAnsweredCount < 5 ? 0.5 : 1.0)

            Text(mandatoryAnsweredCount < 5 ? "Answer all 5 essential questions to save" : "Your extended answers feed into Time-to-Go and AI Coach.")
                .font(.app(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.app(size: 13, weight: .bold)).foregroundColor(color)
            Text(title.uppercased())
                .font(.appMono(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(1.2)
            Spacer()
        }
    }

    /// Mandatory questions always have a non-nil value stored (they start at 3).
    /// The user becomes "answered" the moment they touch the slider — we track
    /// that by comparing against the initial defaults.
    private var mandatoryAnsweredCount: Int {
        mandatoryIds.filter { answers[$0] != nil }.count
    }

    private func mandatorySlider(id: String, title: String, value: Binding<Double>, icon: String,
                                 minLabel: String, maxLabel: String, tip: String,
                                 reverse: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 30, height: 30)
                    Image(systemName: icon).font(.app(size: 12)).foregroundColor(accent)
                }
                Text(title).font(.app(size: 14, weight: .bold))
                Spacer()
                Text("\(Int(value.wrappedValue))/5")
                    .font(.appMono(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Button {
                    withAnimation { showTipFor = showTipFor == id ? nil : id }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.app(size: 14))
                        .foregroundColor(accent)
                }
            }

            if showTipFor == id {
                Text(tip)
                    .font(.app(size: 11))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Slider(value: value, in: 1...5, step: 1) { editing in
                if !editing {
                    answers[id] = [String(Int(value.wrappedValue))]
                }
            }
            .tint(accent)

            HStack {
                Text(minLabel).font(.appMono(size: 9, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Text(maxLabel).font(.appMono(size: 9, weight: .semibold)).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func save() {
        appState.extendedReadinessAnswers = answers
        appState.extendedReadinessAnsweredAt = Date()
        appState.refreshReadiness()
        logTodayGoStage()
        dismiss()
    }

    private func saveSkipped() {
        appState.extendedReadinessAnswers = [:]
        appState.extendedReadinessAnsweredAt = Date()
        dismiss()
    }

    /// After saving, capture today's composite go-stage into the weekly log so
    /// the Basecamp tracker pills light up immediately without waiting for the
    /// Time-to-Go flow.
    private func logTodayGoStage() {
        let iso = Calendar.current.component(.weekday, from: Date()).mapISO
        appState.weeklyGoScores[iso] = appState.timeToGoScore
    }
}

// MARK: - Data model

private struct ReadinessSection: Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    let items: [ReadinessQuestion]
}

private struct ReadinessQuestion: Identifiable {
    let id: String
    let prompt: String
    let options: [String]
    let tip: String
}

// MARK: - FlowOptions — chip row that wraps automatically

/// Lightweight flow layout for multiple-choice chips. Falls back to a plain
/// HStack on iOS <16 via `ViewThatFits`, but we're iOS 17+ anyway so the
/// native `Layout` protocol does the work.
struct FlowOptions: View {
    let options: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option)
                        .font(.app(size: 12, weight: .semibold))
                        .foregroundColor(selected == option ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected == option ? DesignSystem.Colors.accent : Color(white: 0.94))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// FlowLayout is declared in AICoachingGateway.swift
