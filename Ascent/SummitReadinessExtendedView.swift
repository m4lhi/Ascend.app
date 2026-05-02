import SwiftUI

// =========================================
// === DATEI: SummitReadinessExtendedView.swift ===
// === 20-question Summit Readiness assessment ===
// =========================================

struct SummitReadinessExtendedView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // Mandatory (1–5)
    @State private var sleepQuality: Double = 3
    @State private var muscleSoreness: Double = 3
    @State private var jointPain: Double = 1
    @State private var mentalMotivation: Double = 3
    @State private var perceivedHR: Double = 3

    @State private var answers: [String: [String]] = [:]
    @State private var showAssessment: Bool = false
    @State private var showTipFor: String? = nil
    @State private var showSkipWarning = false

    // Bar animation
    @State private var barProgress: Double = 0
    @State private var squeezeAmount: CGFloat = 0
    @State private var charBounces: [CGFloat] = [0, 0, 0, 0]
    @State private var shimmerPhase: CGFloat = -0.5

    private let accent = DesignSystem.Colors.accent

    private var readinessScore: Int { appState.timeToGoScore }

    private var barColor: Color {
        switch readinessScore {
        case ..<35: return Color(red: 0.80, green: 0.22, blue: 0.20)
        case ..<60: return Color(red: 0.92, green: 0.62, blue: 0.12)
        case ..<80: return Color(red: 0.10, green: 0.64, blue: 0.60)
        default:    return Color(red: 0.08, green: 0.66, blue: 0.44)
        }
    }

    // Vivid left-to-right gradient on the fill
    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [barColor.opacity(0.75), barColor, barColor.opacity(0.88)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var statusLabel: String {
        switch readinessScore {
        case ..<35: return "NOT READY"
        case ..<60: return "GETTING THERE"
        case ..<80: return "ALMOST READY"
        default:    return "SUMMIT READY"
        }
    }

    private let mandatoryIds = ["sleep", "soreness", "joints", "motivation", "hr"]

    private let sections: [ReadinessSection] = [
        .init(title: "Nutrition & Fuel", icon: "fork.knife", items: [
            .init(id: "hydration", prompt: "Hydration over last 24h", options: ["Excellent (>3L)", "Adequate (2-3L)", "Low (<2L)", "Dehydrated"], tip: "Dehydration >2% bodyweight halves aerobic capacity at altitude."),
            .init(id: "lastMeal", prompt: "When did you last eat?", options: ["<1h ago", "1-3h ago", "3-6h ago", ">6h ago"], tip: "Below 3000 kcal/day in preparation weeks risks glycogen depletion on summit day."),
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
            Group {
                if showAssessment {
                    ScrollView {
                        VStack(spacing: 22) {
                            assessmentHeader
                            mandatorySection
                            ForEach(sections) { section in
                                extendedSection(section)
                            }
                            saveSection
                        }
                        .padding(.bottom, 40)
                    }
                    .scrollContentBackground(.hidden)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    historyView
                        .transition(.opacity)
                        .onAppear { runBarAnimation() }
                }
            }
            .background(.clear)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showAssessment {
                        Button("Back") {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                showAssessment = false
                            }
                        }
                    } else {
                        Button("Close") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if showAssessment {
                        Button("Skip") { showSkipWarning = true }
                            .foregroundColor(.orange)
                    }
                }
            }
            .alert("Skip at your own risk", isPresented: $showSkipWarning) {
                Button("Skip anyway", role: .destructive) { saveSkipped() }
                Button("Continue assessment", role: .cancel) { }
            } message: {
                Text("Skipping means no subjective readiness factors feed into your Time-to-Go score. We strongly recommend answering the 5 essential questions — they take under 60 seconds.")
            }
            .onAppear {
                if appState.readinessHistory.isEmpty && appState.extendedReadinessAnsweredAt == nil {
                    showAssessment = true
                }
                answers = appState.extendedReadinessAnswers
                for (id, defaultVal) in [("sleep", sleepQuality), ("soreness", muscleSoreness),
                                          ("joints", jointPain), ("motivation", mentalMotivation),
                                          ("hr", perceivedHR)] {
                    if answers[id] == nil {
                        answers[id] = [String(Int(defaultVal))]
                    }
                }
            }
        }
        .background(.clear)
        .adaptiveSheetBackground()
    }

    // MARK: - Bar animation

    private func runBarAnimation() {
        guard appState.readiness != nil else { return }

        // Reset state without animation — otherwise SwiftUI animates the bar shrinking to 0,
        // which creates the "thin bar that pops in late" delay the user reported.
        var noAnim = Transaction()
        noAnim.disablesAnimations = true
        withTransaction(noAnim) {
            barProgress = 0
            squeezeAmount = 0
            shimmerPhase = -0.5
            charBounces = Array(repeating: 0, count: "\(readinessScore)%".count)
        }

        // 1. Squeeze — bar pinches at the fill edge as it launches
        withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
            squeezeAmount = 0.80
        }

        // 2. Bar fills with a single elastic spring (no extra delay — that's what made it sit thin)
        withAnimation(.spring(response: 0.95, dampingFraction: 0.62)) {
            barProgress = Double(readinessScore) / 100.0
        }

        // 3. Release squeeze once fill arrives
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.40)) {
                squeezeAmount = 0
            }
        }

        // 4. Digits bounce in staggered
        let chars = Array("\(readinessScore)%")
        for (i, _) in chars.enumerated() {
            let t = 0.22 + Double(i) * 0.07
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard i < charBounces.count else { return }
                withAnimation(.spring(response: 0.13, dampingFraction: 0.25)) { charBounces[i] = -14 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.50)) { charBounces[i] = 0 }
                }
            }
        }

        // 5. Shimmer sweeps after bar fills
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.70)) {
                shimmerPhase = 1.5
            }
        }
    }

    // MARK: - History / Score view

    private var historyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Label row
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SUMMIT READINESS")
                            .font(.appMono(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.8)
                        if let lastDate = appState.extendedReadinessAnsweredAt {
                            Text("Updated \(relativeDateString(lastDate))")
                                .font(.app(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(barColor)
                        .animation(.easeOut(duration: 0.5), value: barColor)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 16)

                // ── The bar ──────────────────────────────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {

                        // Track
                        Rectangle()
                            .fill(barColor.opacity(0.10))

                        // Animated fill
                        Rectangle()
                            .fill(fillGradient)
                            // Static top-half gloss
                            .overlay(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            // Diagonal shimmer sweep
                            .overlay(
                                LinearGradient(
                                    colors: [.clear,
                                             Color.white.opacity(0.0),
                                             Color.white.opacity(0.55),
                                             Color.white.opacity(0.0),
                                             .clear],
                                    startPoint: UnitPoint(x: shimmerPhase - 0.25, y: 0),
                                    endPoint:   UnitPoint(x: shimmerPhase + 0.25, y: 1)
                                )
                                .blendMode(.plusLighter)
                            )
                            .frame(width: geo.size.width * barProgress)
                            .clipShape(SpongeBendShape(squeeze: squeezeAmount, fillProgress: barProgress))

                        // Score digits — bounce in as bar sweeps
                        HStack(spacing: 1) {
                            ForEach(Array(Array("\(readinessScore)%").enumerated()), id: \.offset) { i, ch in
                                Text(String(ch))
                                    .font(.appMono(size: 46, weight: .black))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                                    .offset(y: i < charBounces.count ? charBounces[i] : 0)
                            }
                        }
                        .padding(.leading, 22)
                    }
                }
                .frame(height: 78)
                // ─────────────────────────────────────────────

                // Status + recommendation
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(statusLabel)
                        .font(.appMono(size: 10, weight: .bold))
                        .foregroundColor(barColor)
                        .tracking(1.4)
                        .animation(.easeOut(duration: 0.3), value: statusLabel)
                    Spacer()
                    if let readiness = appState.readiness {
                        Text("\(readiness.totalScore) / 100")
                            .font(.appMono(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)

                if let readiness = appState.readiness {
                    Text(readiness.recommendation)
                        .font(.app(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // Sub-scores
                    HStack(spacing: 8) {
                        subScorePill(label: "Physio",   score: readiness.physiologicalScore)
                        subScorePill(label: "Workload", score: readiness.workloadScore)
                        subScorePill(label: "Altitude", score: readiness.altitudeScore)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }

                // Calendar
                if !appState.readinessHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LAST 90 DAYS")
                            .font(.appMono(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.4)
                            .padding(.horizontal, 20)
                        ReadinessCalendarGrid(history: appState.readinessHistory)
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 28)
                }

                // CTA
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { showAssessment = true }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.app(size: 16, weight: .bold))
                        Text(appState.readiness == nil ? "Start Assessment" : "Reassess Today")
                            .font(.app(size: 16, weight: .black))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: accent.opacity(0.30), radius: 12, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func subScorePill(label: String, score: Int) -> some View {
        let c = colorForScore(score)
        return HStack(spacing: 6) {
            Circle().fill(c).frame(width: 6, height: 6)
            Text(label)
                .font(.appMono(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.8)
            Spacer()
            Text("\(score)")
                .font(.appMono(size: 12, weight: .black))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Assessment Header (clean form header — no bar)

    private var assessmentHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SUMMIT READINESS")
                        .font(.appMono(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.6)
                    Text("20 Questions")
                        .font(.app(size: 26, weight: .black))
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(accent.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accent)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 14)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * (Double(mandatoryAnsweredCount) / 5.0))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: mandatoryAnsweredCount)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)

            HStack(spacing: 5) {
                Circle()
                    .fill(mandatoryAnsweredCount >= 5 ? accent : Color.orange)
                    .frame(width: 5, height: 5)
                Text("\(mandatoryAnsweredCount)/5 essential questions answered")
                    .font(.appMono(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Sections

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
                ForEach(section.items) { item in questionCard(item) }
            }
        }
        .padding(.horizontal, 16)
    }

    private func questionCard(_ item: ReadinessQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.prompt).font(.app(size: 14, weight: .bold))
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
                    Image(systemName: "lightbulb.fill").font(.app(size: 11)).foregroundColor(.orange)
                    Text(item.tip).font(.app(size: 12)).foregroundColor(.secondary)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var saveSection: some View {
        VStack(spacing: 12) {
            Button(action: save) {
                Text("Save & See Results")
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(mandatoryAnsweredCount >= 5 ? accent : Color.gray.opacity(0.35))
                    )
            }
            .disabled(mandatoryAnsweredCount < 5)
            Text(mandatoryAnsweredCount < 5
                 ? "Answer all 5 essential questions to save"
                 : "Your answers feed into Time-to-Go and AI Coach.")
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

    private var mandatoryAnsweredCount: Int {
        mandatoryIds.filter { answers[$0] != nil }.count
    }

    private func mandatorySlider(id: String, title: String, value: Binding<Double>, icon: String,
                                 minLabel: String, maxLabel: String, tip: String,
                                 reverse: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.12))
                        .frame(width: 30, height: 30)
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
                    Image(systemName: "info.circle").font(.app(size: 14)).foregroundColor(accent)
                }
            }
            if showTipFor == id {
                Text(tip).font(.app(size: 11)).foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Slider(value: value, in: 1...5, step: 1) { editing in
                if !editing { answers[id] = [String(Int(value.wrappedValue))] }
            }
            .tint(accent)
            HStack {
                Text(minLabel).font(.appMono(size: 9, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Text(maxLabel).font(.appMono(size: 9, weight: .semibold)).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case ..<35: return Color(red: 0.80, green: 0.22, blue: 0.20)
        case ..<60: return Color(red: 0.92, green: 0.62, blue: 0.12)
        case ..<80: return Color(red: 0.10, green: 0.64, blue: 0.60)
        default:    return Color(red: 0.08, green: 0.66, blue: 0.44)
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter(); fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    private func save() {
        appState.extendedReadinessAnswers = answers
        appState.extendedReadinessAnsweredAt = Date()
        appState.refreshReadiness()
        logTodayGoStage()
        appState.recordReadinessScore(appState.timeToGoScore)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showAssessment = false
        }
    }

    private func saveSkipped() {
        appState.extendedReadinessAnswers = [:]
        appState.extendedReadinessAnsweredAt = Date()
        dismiss()
    }

    private func logTodayGoStage() {
        let iso = Calendar.current.component(.weekday, from: Date()).mapISO
        appState.weeklyGoScores[iso] = appState.timeToGoScore
    }
}

// MARK: - Data model

private struct ReadinessSection: Identifiable {
    var id: String { title }
    let title: String; let icon: String; let items: [ReadinessQuestion]
}
private struct ReadinessQuestion: Identifiable {
    let id: String; let prompt: String; let options: [String]; let tip: String
}

// MARK: - FlowOptions

struct FlowOptions: View {
    let options: [String]; let selected: String?; let onSelect: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button { onSelect(option) } label: {
                    Text(option)
                        .font(.app(size: 12, weight: .semibold))
                        .foregroundColor(selected == option ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(selected == option
                            ? DesignSystem.Colors.accent
                            : Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// FlowLayout is declared in AICoachingGateway.swift

// MARK: - Sponge bend shape

private struct SpongeBendShape: Shape {
    var squeeze: CGFloat
    var fillProgress: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(squeeze, fillProgress) }
        set { squeeze = newValue.first; fillProgress = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let inset = rect.height * squeeze * 0.46
        let pinchX = rect.width * fillProgress * 0.5
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: pinchX, y: rect.minY + inset)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: pinchX, y: rect.maxY - inset)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Readiness Calendar Grid

struct ReadinessCalendarGrid: View {
    let history: [String: Int]
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private var weeks: [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -89, to: today) else { return [] }
        let weekday = cal.component(.weekday, from: start)
        let isoOffset = ((weekday + 5) % 7)
        guard let gridStart = cal.date(byAdding: .day, value: -isoOffset, to: start) else { return [] }
        var result: [[Date?]] = []; var cursor = gridStart
        while cursor <= today {
            var week: [Date?] = []
            for _ in 0..<7 {
                week.append(cursor < start ? nil : (cursor <= today ? cursor : nil))
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            result.append(week)
        }
        return result
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                ForEach(["M","T","W","T","F","S","S"].indices, id: \.self) { i in
                    Text(["M","T","W","T","F","S","S"][i])
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks.indices, id: \.self) { wi in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { di in
                        if let day = weeks[wi][di] {
                            let score = history[dateFmt.string(from: day)]
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(dotColor(for: score))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    private func dotColor(for score: Int?) -> Color {
        guard let s = score else { return Color.gray.opacity(0.13) }
        if s > 80 { return Color(red: 0.08, green: 0.66, blue: 0.44) }
        if s > 60 { return Color(red: 0.10, green: 0.64, blue: 0.60) }
        if s > 35 { return Color(red: 0.92, green: 0.62, blue: 0.12) }
        return Color(red: 0.80, green: 0.22, blue: 0.20)
    }
}
