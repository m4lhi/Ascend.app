import SwiftUI
import MapKit
import CoreLocation

// =========================================
// === DATEI: GoalDetailSheet.swift ===
// === Pastel goal detail with map + bento + progress ===
// =========================================
//
// Iteration 17 rewrite. paperWarm sheet with editorial title,
// 2×2 bento stats grid, readiness progress card (snapshot → now
// delta), notes card, pro-analysis shortcut, and a primary
// alpenglow "Begin Climbing" CTA when a real Mountain row is
// resolvable.

struct GoalDetailSheet: View {
    let goal: Goal
    let onStartMission: (Mountain) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var discoveryVM: DiscoveryViewModel
    @EnvironmentObject var readinessVM: ReadinessViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showProAnalysis = false
    @State private var showDeleteConfirm = false

    /// Look the full Mountain row up from the discovery pool so we
    /// can pass it to Pro Analysis and Begin Climbing. Free-form
    /// goals (no mountainId) can still be viewed/edited/deleted.
    private var resolvedMountain: Mountain? {
        guard let id = goal.mountainId else { return nil }
        let pool = discoveryVM.recommendedPeaks + discoveryVM.suggestedRoutes
        return pool.first(where: { $0.id == id })
    }

    private var daysLabel: String {
        guard let days = goal.daysUntilTarget else { return "No deadline" }
        if days < 0  { return "\(-days) days past due" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    private var daysColor: Color {
        guard let days = goal.daysUntilTarget else {
            return DesignSystem.Colors.inkWarm.opacity(0.62)
        }
        if days < 0  { return DesignSystem.Colors.ember }
        if days <= 7 { return DesignSystem.Colors.alpenglow }
        return DesignSystem.Colors.glacierDeep
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.paperWarm.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {

                        heroSection

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(goal.mountainName)
                                .font(DesignSystem.Typography.title1Inter)
                                .foregroundStyle(DesignSystem.Colors.inkWarm)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                Text("\(goal.elevationM) m")
                                    .font(DesignSystem.Typography.bodyInter)
                                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                                    .monospacedDigit()
                                Text("·").foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                                Text(daysLabel)
                                    .font(DesignSystem.Typography.bodyInter)
                                    .foregroundStyle(daysColor)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        statsBentoGrid
                            .padding(.horizontal, DesignSystem.Spacing.lg)

                        if let snapshot = goal.readinessSnapshot,
                           let current = readinessVM.readiness {
                            progressCard(snapshot: snapshot, current: current.totalScore)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        if !goal.notes.isEmpty {
                            notesCard
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        if resolvedMountain != nil {
                            proAnalysisCard
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        Spacer().frame(height: DesignSystem.Spacing.md)

                        if let m = resolvedMountain {
                            Button {
                                onStartMission(m)
                            } label: {
                                Text("Begin Climbing")
                                    .font(DesignSystem.Typography.bodyEmphasisInter)
                                    .foregroundStyle(DesignSystem.Colors.inkOnSand)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                    .background(Capsule().fill(DesignSystem.Colors.alpenglow))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        Spacer().frame(height: DesignSystem.Spacing.xl)
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle(goal.mountainName)
            .navigationBarTitleDisplayMode(.inline)
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
                    Menu {
                        Button { onEdit() } label: {
                            Label("Edit goal", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete goal", systemImage: "trash")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.surfaceWarm)
                                .frame(width: 32, height: 32)
                            HStack(spacing: 2) {
                                Circle().fill(DesignSystem.Colors.inkWarm.opacity(0.62)).frame(width: 3, height: 3)
                                Circle().fill(DesignSystem.Colors.inkWarm.opacity(0.62)).frame(width: 3, height: 3)
                                Circle().fill(DesignSystem.Colors.inkWarm.opacity(0.62)).frame(width: 3, height: 3)
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete this goal?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This can't be undone.")
            }
            .sheet(isPresented: $showProAnalysis) {
                if let m = resolvedMountain {
                    MountainProAnalysisSheet(mountain: m)
                        .presentationDetents([.large])
                }
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        if let coord = goal.coordinate {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 8000, longitudinalMeters: 8000)
            Map(initialPosition: .region(region), interactionModes: []) {
                Annotation(goal.mountainName, coordinate: coord) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.alpenglow)
                            .frame(width: 32, height: 32)
                        MountainGlyph()
                            .foregroundStyle(DesignSystem.Colors.paperWarm)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft))
            .padding(.horizontal, DesignSystem.Spacing.lg)
        } else {
            VStack {
                Image("hero-ready")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                    .fill(DesignSystem.Colors.alpenglowSoft.opacity(0.5))
            )
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Bento stats

    private var statsBentoGrid: some View {
        let createdFmt = DateFormatter()
        createdFmt.dateStyle = .medium
        let createdString = createdFmt.string(from: goal.createdAt)

        let deadlineString: String = {
            guard let d = goal.targetDate else { return "Not set" }
            let f = DateFormatter()
            f.dateStyle = .medium
            return f.string(from: d)
        }()

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: DesignSystem.Spacing.sm),
            GridItem(.flexible(), spacing: DesignSystem.Spacing.sm)
        ], spacing: DesignSystem.Spacing.sm) {

            statBentoCard(
                label: "Elevation",
                value: "\(goal.elevationM) m",
                background: DesignSystem.Colors.sageCard,
                textColor: DesignSystem.Colors.inkOnSage
            )

            statBentoCard(
                label: "Days remaining",
                value: daysLabel,
                background: DesignSystem.Colors.iceGlacierCard,
                textColor: DesignSystem.Colors.inkOnIce
            )

            statBentoCard(
                label: "Deadline",
                value: deadlineString,
                background: DesignSystem.Colors.sandCard,
                textColor: DesignSystem.Colors.inkOnSand
            )

            statBentoCard(
                label: "Set on",
                value: createdString,
                background: DesignSystem.Colors.sageCard,
                textColor: DesignSystem.Colors.inkOnSage
            )
        }
    }

    private func statBentoCard(label: String, value: String, background: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(textColor.opacity(0.72))
            Text(value)
                .font(DesignSystem.Typography.title3Inter)
                .foregroundStyle(textColor)
                .monospacedDigit()
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(background)
        )
    }

    // MARK: - Progress card

    private func progressCard(snapshot: Int, current: Int) -> some View {
        let delta = current - snapshot
        let deltaText: String = {
            if delta > 0 { return "+\(delta)%" }
            if delta < 0 { return "\(delta)%" }
            return "0%"
        }()
        let deltaColor: Color = {
            if delta > 0 { return DesignSystem.Colors.meadow }
            if delta < 0 { return DesignSystem.Colors.ember }
            return DesignSystem.Colors.inkWarm.opacity(0.62)
        }()

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Readiness toward this goal")
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                .tracking(0.5)

            HStack(spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                    Text("\(snapshot)%")
                        .font(DesignSystem.Typography.title3Inter)
                        .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                        .monospacedDigit()
                }

                Text("→")
                    .font(DesignSystem.Typography.bodyInter)
                    .foregroundStyle(DesignSystem.Colors.inkFaintWarm)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Now")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                    Text("\(current)%")
                        .font(DesignSystem.Typography.title3Inter)
                        .foregroundStyle(DesignSystem.Colors.inkWarm)
                        .monospacedDigit()
                }

                Spacer()

                Text(deltaText)
                    .font(DesignSystem.Typography.bodyEmphasisInter)
                    .foregroundStyle(deltaColor)
                    .monospacedDigit()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(deltaColor.opacity(0.12)))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.Colors.surfaceWarm)
                        .frame(height: 6)
                    Capsule()
                        .fill(DesignSystem.Colors.alpenglow)
                        .frame(width: geo.size.width * (Double(current) / 100.0), height: 6)
                }
            }
            .frame(height: 6)
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

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Notes")
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                .tracking(0.5)

            Text(goal.notes)
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .fill(DesignSystem.Colors.paperWarm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Pro analysis card

    private var proAnalysisCard: some View {
        Button { showProAnalysis = true } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro analysis")
                        .font(DesignSystem.Typography.bodyEmphasisInter)
                        .foregroundStyle(DesignSystem.Colors.inkOnIce)
                    Text("Weather · avalanche · slope")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkOnIce.opacity(0.62))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.inkOnIce.opacity(0.62))
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft)
                    .fill(DesignSystem.Colors.iceGlacierCard)
            )
        }
        .buttonStyle(.plain)
    }
}
