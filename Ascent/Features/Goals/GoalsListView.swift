import SwiftUI
import CoreLocation

// User's list of climbing goals — sorted by next-up deadline, then by creation date.
struct GoalsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showAddGoal = false
    @State private var goalToEdit: Goal?
    @State private var goalToShow: Goal?

    private let accent = DesignSystem.Colors.accent

    private var sortedGoals: [Goal] {
        appState.goals.sorted { a, b in
            switch (a.targetDate, b.targetDate) {
            case (let l?, let r?): return l < r
            case (.some, .none):   return true   // dated goals first
            case (.none, .some):   return false
            case (.none, .none):   return a.createdAt > b.createdAt
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if sortedGoals.isEmpty {
                            emptyState
                                .padding(.top, 40)
                        } else {
                            ForEach(sortedGoals) { goal in
                                Button { goalToShow = goal } label: {
                                    goalRow(goal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddGoal = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet { goal in
                    appState.goals.append(goal)
                }
                .environmentObject(appState)
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
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
                .preferredColorScheme(.dark)
            }
            .sheet(item: $goalToShow) { goal in
                GoalDetailSheet(
                    goal: goal,
                    onStartMission: { mountain in
                        appState.activeMountain = mountain
                        withAnimation { appState.isTrackerActive = true }
                        dismiss() // close the goals list
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
                .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "flag.2.crossed")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(accent.gradient)
            Text("No goals yet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("Add a peak you want to climb. Your readiness, training, and weather forecast will all reference your active goal.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button { showAddGoal = true } label: {
                Label("Add First Goal", systemImage: "plus")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Goal row

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.mountainName)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(goal.elevationM)m")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    if let days = goal.daysUntilTarget {
                        Text("·")
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        if days < 0 {
                            Text("Past due")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                        } else if days == 0 {
                            Text("Today")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange)
                        } else {
                            Text("In \(days) day\(days == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(accent)
                        }
                    }
                }
                if !goal.notes.isEmpty {
                    Text(goal.notes)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
    }
}

// MARK: - Add Goal sheet (peak picker)

struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var discoveryVM: DiscoveryViewModel
    let onSave: (Goal) -> Void

    @State private var search: String = ""
    @State private var hasDeadline = false
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 60) // ~2 months
    @State private var notes = ""
    @State private var selectedMountain: Mountain?
    @State private var customName: String = ""
    @State private var customElevation: String = ""

    private let accent = DesignSystem.Colors.accent

    private var filteredPeaks: [Mountain] {
        let candidates = discoveryVM.recommendedPeaks + discoveryVM.suggestedRoutes
        let unique = Array(Set(candidates))
        if search.isEmpty {
            return Array(unique.prefix(20))
        }
        return unique.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Peak") {
                    TextField("Search peaks…", text: $search)
                        .textInputAutocapitalization(.words)
                    if !filteredPeaks.isEmpty {
                        ForEach(filteredPeaks) { mountain in
                            Button { selectedMountain = mountain } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mountain.name).foregroundColor(.white)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        Text("\(mountain.elevation)m · \(mountain.region)")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                    }
                                    Spacer()
                                    if selectedMountain?.id == mountain.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(accent)
                                    }
                                }
                            }
                        }
                    }
                }
                if selectedMountain == nil {
                    Section("Or add a custom peak") {
                        TextField("Name", text: $customName)
                        TextField("Elevation (m)", text: $customElevation)
                            .keyboardType(.numberPad)
                    }
                }
                Section("Deadline") {
                    Toggle("Set a target date", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("Target", selection: $targetDate, in: Date()..., displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Why this peak? Plan? Route?", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGoal() }
                        .bold()
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        if selectedMountain != nil { return true }
        return !customName.trimmingCharacters(in: .whitespaces).isEmpty &&
               (Int(customElevation) ?? 0) > 0
    }

    private func saveGoal() {
        let date = hasDeadline ? targetDate : nil
        let snapshot = appState.readiness.map { Int($0.totalScore) }
        let goal: Goal
        if let m = selectedMountain {
            goal = Goal(from: m, targetDate: date, notes: notes, readinessSnapshot: snapshot)
        } else {
            goal = Goal(
                mountainId: nil,
                mountainName: customName,
                elevationM: Int(customElevation) ?? 0,
                latitude: nil, longitude: nil,
                targetDate: date,
                notes: notes,
                readinessSnapshot: snapshot
            )
        }
        onSave(goal)
        dismiss()
    }
}

// MARK: - Edit/Delete sheet

struct EditGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let goal: Goal
    let onSave: (Goal) -> Void
    let onDelete: (UUID) -> Void

    @State private var notes: String
    @State private var hasDeadline: Bool
    @State private var targetDate: Date

    init(goal: Goal, onSave: @escaping (Goal) -> Void, onDelete: @escaping (UUID) -> Void) {
        self.goal = goal
        self.onSave = onSave
        self.onDelete = onDelete
        _notes = State(initialValue: goal.notes)
        _hasDeadline = State(initialValue: goal.targetDate != nil)
        _targetDate = State(initialValue: goal.targetDate ?? Date().addingTimeInterval(60 * 60 * 24 * 60))
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "mountain.2.fill")
                            .font(.title2)
                            .foregroundColor(DesignSystem.Colors.accent)
                        VStack(alignment: .leading) {
                            Text(goal.mountainName)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            Text("\(goal.elevationM)m")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                Section("Deadline") {
                    Toggle("Target date", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("Target", selection: $targetDate, displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Button(role: .destructive) {
                        onDelete(goal.id)
                        dismiss()
                    } label: {
                        Label("Delete Goal", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = goal
                        updated.notes = notes
                        updated.targetDate = hasDeadline ? targetDate : nil
                        onSave(updated)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
