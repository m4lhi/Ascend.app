import SwiftUI
import CoreLocation

// =========================================
// === DATEI: GoalsListView.swift ===
// === Goals list + add/edit sheets, pastel ===
// =========================================
//
// Iteration 17 rewrite. Replaces the Form-based goal sheets with
// pastel cards, drops SF Symbols for goal/mountain elements, and
// adds:
//
//   - Pastel paperWarm screen background.
//   - Editorial "No goals yet" empty state with hero asset + CTA.
//   - GoalCard with primary-goal differentiation (alpenglowSoft
//     background + "next" badge for the active focus).
//   - Add sheet with single-page search → select-or-create flow,
//     auto-detect "Add 'X' as custom" pill when the search has
//     no matches.
//   - Edit sheet with deadline toggle + notes + destructive delete.

struct GoalsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showAddGoal = false
    @State private var goalToEdit: Goal?
    @State private var goalToShow: Goal?

    private var sortedGoals: [Goal] {
        appState.goals.sorted { a, b in
            switch (a.targetDate, b.targetDate) {
            case (let l?, let r?): return l < r
            case (.some, .none):   return true
            case (.none, .some):   return false
            case (.none, .none):   return a.createdAt > b.createdAt
            }
        }
    }

    private var primaryGoalId: UUID? {
        appState.goals.primary?.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.paperWarm.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    if sortedGoals.isEmpty {
                        EmptyGoalsState(onAddGoal: { showAddGoal = true })
                            .padding(.top, DesignSystem.Spacing.xxl)
                    } else {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(sortedGoals) { goal in
                                Button { goalToShow = goal } label: {
                                    GoalCard(
                                        goal: goal,
                                        isPrimary: goal.id == primaryGoalId
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.surfaceWarm)
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                        }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddGoal = true } label: {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.glacierSoft)
                                .frame(width: 32, height: 32)
                            ZStack {
                                Rectangle()
                                    .fill(DesignSystem.Colors.glacierDeep)
                                    .frame(width: 11, height: 1.5)
                                Rectangle()
                                    .fill(DesignSystem.Colors.glacierDeep)
                                    .frame(width: 1.5, height: 11)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet { goal in
                    appState.goals.append(goal)
                }
                .environmentObject(appState)
                .presentationDetents([.large])
            }
            .sheet(item: $goalToEdit) { goal in
                EditGoalSheet(
                    goal: goal,
                    onSave: { updated in
                        if let idx = appState.goals.firstIndex(where: { $0.id == updated.id }) {
                            appState.goals[idx] = updated
                        }
                    },
                    onDelete: { id in
                        appState.goals.removeAll { $0.id == id }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $goalToShow) { goal in
                GoalDetailSheet(
                    goal: goal,
                    onStartMission: { mountain in
                        appState.activeMountain = mountain
                        withAnimation { appState.isTrackerActive = true }
                        dismiss()
                    },
                    onEdit: {
                        goalToShow = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            goalToEdit = goal
                        }
                    },
                    onDelete: {
                        appState.goals.removeAll { $0.id == goal.id }
                    }
                )
                .environmentObject(appState)
                .presentationDetents([.large])
            }
        }
    }
}

// MARK: - Empty state

struct EmptyGoalsState: View {
    let onAddGoal: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image("hero-ready")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 165)

            Text("No goals yet")
                .font(DesignSystem.Typography.title2Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)

            Text("Pick a peak you want to climb.\nYour readiness, training, and weather forecast will reference your active goal.")
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAddGoal) {
                Text("Add your first goal")
                    .font(DesignSystem.Typography.bodyEmphasisInter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .background(Capsule().fill(DesignSystem.Colors.alpenglow))
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Goal card row

struct GoalCard: View {
    let goal: Goal
    let isPrimary: Bool

    private var statusInfo: (label: String, color: Color)? {
        guard let days = goal.daysUntilTarget else { return nil }
        if days < 0  { return ("Past due", DesignSystem.Colors.ember) }
        if days == 0 { return ("Today",    DesignSystem.Colors.alpenglow) }
        if days == 1 { return ("Tomorrow", DesignSystem.Colors.alpenglow) }
        if days <= 7 { return ("In \(days) days", DesignSystem.Colors.alpenglow) }
        return ("In \(days) days", DesignSystem.Colors.inkWarm.opacity(0.62))
    }

    private var cardBackground: Color {
        if isPrimary { return DesignSystem.Colors.alpenglowSoft }
        return DesignSystem.Colors.surfaceWarm
    }

    private var textColor: Color {
        isPrimary ? DesignSystem.Colors.inkOnSand : DesignSystem.Colors.inkWarm
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {

            ZStack {
                Circle()
                    .fill(isPrimary
                          ? DesignSystem.Colors.alpenglow.opacity(0.18)
                          : DesignSystem.Colors.surfaceWarm)
                    .frame(width: 48, height: 48)
                MountainGlyph()
                    .foregroundStyle(isPrimary
                                     ? DesignSystem.Colors.alpenglow
                                     : DesignSystem.Colors.glacierDeep)
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: 6) {
                    Text(goal.mountainName)
                        .font(DesignSystem.Typography.title3Inter)
                        .foregroundStyle(textColor)
                        .lineLimit(1)

                    if isPrimary {
                        Text("next")
                            .font(DesignSystem.Typography.kickerInter)
                            .foregroundStyle(DesignSystem.Colors.alpenglow)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(DesignSystem.Colors.alpenglow.opacity(0.15)))
                    }
                }

                HStack(spacing: 6) {
                    Text("\(goal.elevationM) m")
                        .font(DesignSystem.Typography.subheadInter)
                        .foregroundStyle(textColor.opacity(0.72))
                        .monospacedDigit()

                    if let status = statusInfo {
                        Text("·").foregroundStyle(textColor.opacity(0.4))
                        Text(status.label)
                            .font(DesignSystem.Typography.subheadInter)
                            .foregroundStyle(status.color)
                    }
                }

                if !goal.notes.isEmpty {
                    Text(goal.notes)
                        .font(DesignSystem.Typography.subheadInter)
                        .foregroundStyle(textColor.opacity(0.72))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(cardBackground)
        )
    }
}

// MARK: - Add goal sheet

struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var discoveryVM: DiscoveryViewModel
    @EnvironmentObject var readinessVM: ReadinessViewModel
    let onSave: (Goal) -> Void

    @State private var searchText: String = ""
    @State private var selectedMountain: Mountain?
    @State private var isCustomMode = false
    @State private var customName: String = ""
    @State private var customElevation: String = ""

    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(60 * 60 * 24 * 60)

    @State private var notes: String = ""

    private var filteredPeaks: [Mountain] {
        let pool = discoveryVM.recommendedPeaks + discoveryVM.suggestedRoutes
        let unique = Array(Set(pool))
        if searchText.isEmpty {
            return Array(unique.prefix(8))
        }
        return unique.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var canSave: Bool {
        if isCustomMode {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty
                && (Int(customElevation) ?? 0) > 0
        }
        return selectedMountain != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.paperWarm.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Pick a peak")
                            peakPickerCard
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Deadline · optional")
                            deadlineCard
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Why this peak · optional")
                            notesCard
                        }

                        Spacer().frame(height: DesignSystem.Spacing.xl)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        Text("Save")
                            .font(DesignSystem.Typography.bodyEmphasisInter)
                            .foregroundStyle(canSave
                                             ? DesignSystem.Colors.alpenglow
                                             : DesignSystem.Colors.inkFaintWarm)
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.kickerInter)
            .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
            .tracking(0.5)
    }

    // MARK: - Peak picker

    @ViewBuilder
    private var peakPickerCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 8) {
                Circle()
                    .stroke(DesignSystem.Colors.inkFaintWarm, lineWidth: 1.5)
                    .frame(width: 12, height: 12)

                TextField("Search peaks…", text: $searchText)
                    .font(DesignSystem.Typography.bodyInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                    .textInputAutocapitalization(.words)
                    .onChange(of: searchText) { _, _ in
                        if !filteredPeaks.contains(where: { $0.id == selectedMountain?.id }) {
                            selectedMountain = nil
                        }
                        isCustomMode = false
                    }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.surfaceWarm)
            )

            if !isCustomMode {
                ForEach(filteredPeaks) { mountain in
                    peakRow(mountain)
                }

                if !searchText.isEmpty
                    && !filteredPeaks.contains(where: {
                        $0.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame
                    }) {
                    Button {
                        isCustomMode = true
                        customName = searchText
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Rectangle()
                                    .fill(DesignSystem.Colors.glacierDeep)
                                    .frame(width: 10, height: 1.4)
                                Rectangle()
                                    .fill(DesignSystem.Colors.glacierDeep)
                                    .frame(width: 1.4, height: 10)
                            }
                            .frame(width: 18, height: 18)

                            Text("Add \"\(searchText)\" as custom")
                                .font(DesignSystem.Typography.bodyInter)
                                .foregroundStyle(DesignSystem.Colors.glacierDeep)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                .fill(DesignSystem.Colors.glacierSoft.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .stroke(
                                            DesignSystem.Colors.glacierDeep.opacity(0.3),
                                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                customPeakInputs
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(DesignSystem.Colors.paperWarm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private func peakRow(_ mountain: Mountain) -> some View {
        let isSelected = selectedMountain?.id == mountain.id
        return Button { selectedMountain = mountain } label: {
            HStack(spacing: 10) {
                MountainGlyph()
                    .foregroundStyle(isSelected
                                     ? DesignSystem.Colors.alpenglow
                                     : DesignSystem.Colors.glacierDeep)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(mountain.name)
                        .font(DesignSystem.Typography.bodyEmphasisInter)
                        .foregroundStyle(DesignSystem.Colors.inkWarm)
                    Text("\(mountain.elevation) m · \(mountain.region)")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                        .monospacedDigit()
                }

                Spacer()

                if isSelected {
                    Path { p in
                        p.move(to: CGPoint(x: 4, y: 9))
                        p.addLine(to: CGPoint(x: 8, y: 13))
                        p.addLine(to: CGPoint(x: 14, y: 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(DesignSystem.Colors.alpenglow)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isSelected
                          ? DesignSystem.Colors.alpenglowSoft.opacity(0.5)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var customPeakInputs: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Custom peak — fill in the details:")
                .font(DesignSystem.Typography.subheadInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))

            TextField("Peak name", text: $customName)
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.surfaceWarm)
                )

            TextField("Elevation in meters", text: $customElevation)
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .keyboardType(.numberPad)
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.surfaceWarm)
                )

            Button {
                isCustomMode = false
                customName = ""
                customElevation = ""
            } label: {
                Text("← Back to search")
                    .font(DesignSystem.Typography.kickerInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Spacing.xs)
        }
    }

    // MARK: - Deadline + notes

    @ViewBuilder
    private var deadlineCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: $hasDeadline.animation()) {
                Text("Set a deadline")
                    .font(DesignSystem.Typography.bodyInter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
            }
            .tint(DesignSystem.Colors.alpenglow)

            if hasDeadline {
                DatePicker(
                    "Target",
                    selection: $deadline,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(DesignSystem.Colors.alpenglow)
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(DesignSystem.Colors.paperWarm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            TextField("Plan, route, motivation…", text: $notes, axis: .vertical)
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .lineLimit(2...5)
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.surfaceWarm)
                )
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(DesignSystem.Colors.paperWarm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private func save() {
        let date = hasDeadline ? deadline : nil
        let snapshot = readinessVM.readiness.map { Int($0.totalScore) }
        let goal: Goal

        if isCustomMode {
            goal = Goal(
                mountainId: nil,
                mountainName: customName,
                elevationM: Int(customElevation) ?? 0,
                latitude: nil,
                longitude: nil,
                targetDate: date,
                notes: notes,
                readinessSnapshot: snapshot
            )
        } else if let m = selectedMountain {
            goal = Goal(from: m, targetDate: date, notes: notes, readinessSnapshot: snapshot)
        } else {
            return
        }

        onSave(goal)
        dismiss()
    }
}

// MARK: - Edit goal sheet

struct EditGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let goal: Goal
    let onSave: (Goal) -> Void
    let onDelete: (UUID) -> Void

    @State private var notes: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var showDeleteConfirm = false

    init(goal: Goal, onSave: @escaping (Goal) -> Void, onDelete: @escaping (UUID) -> Void) {
        self.goal = goal
        self.onSave = onSave
        self.onDelete = onDelete
        _notes = State(initialValue: goal.notes)
        _hasDeadline = State(initialValue: goal.targetDate != nil)
        _deadline = State(initialValue: goal.targetDate ?? Date().addingTimeInterval(60 * 60 * 24 * 60))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.paperWarm.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.alpenglow.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                MountainGlyph()
                                    .foregroundStyle(DesignSystem.Colors.alpenglow)
                                    .frame(width: 20, height: 20)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(goal.mountainName)
                                    .font(DesignSystem.Typography.title3Inter)
                                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                                Text("\(goal.elevationM) m")
                                    .font(DesignSystem.Typography.kickerInter)
                                    .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                                    .monospacedDigit()
                            }
                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                .fill(DesignSystem.Colors.alpenglowSoft.opacity(0.5))
                        )

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Deadline")
                                .font(DesignSystem.Typography.kickerInter)
                                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                                .tracking(0.5)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Toggle(isOn: $hasDeadline.animation()) {
                                    Text("Target date set")
                                        .font(DesignSystem.Typography.bodyInter)
                                        .foregroundStyle(DesignSystem.Colors.inkWarm)
                                }
                                .tint(DesignSystem.Colors.alpenglow)

                                if hasDeadline {
                                    DatePicker("", selection: $deadline, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .tint(DesignSystem.Colors.alpenglow)
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                    .fill(DesignSystem.Colors.paperWarm)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                    .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
                            )
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Notes")
                                .font(DesignSystem.Typography.kickerInter)
                                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                                .tracking(0.5)

                            TextField("Notes", text: $notes, axis: .vertical)
                                .font(DesignSystem.Typography.bodyInter)
                                .foregroundStyle(DesignSystem.Colors.inkWarm)
                                .lineLimit(2...5)
                                .padding(DesignSystem.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .fill(DesignSystem.Colors.surfaceWarm)
                                )
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                        .fill(DesignSystem.Colors.paperWarm)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                        .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
                                )
                        }

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete goal")
                                .font(DesignSystem.Typography.bodyEmphasisInter)
                                .foregroundStyle(DesignSystem.Colors.ember)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                                        .fill(DesignSystem.Colors.ember.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, DesignSystem.Spacing.md)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationTitle("Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        var updated = goal
                        updated.notes = notes
                        updated.targetDate = hasDeadline ? deadline : nil
                        onSave(updated)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(DesignSystem.Typography.bodyEmphasisInter)
                            .foregroundStyle(DesignSystem.Colors.alpenglow)
                    }
                }
            }
            .confirmationDialog(
                "Delete this goal?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete(goal.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}
