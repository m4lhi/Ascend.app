import SwiftUI
import MapKit
import CoreLocation

// Detailed goal view with map preview, days countdown, pro analysis shortcut,
// and quick actions (start mission, edit, delete).
struct GoalDetailSheet: View {
    let goal: Goal
    let onStartMission: (Mountain) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var discoveryVM: DiscoveryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showProAnalysis = false

    private let accent = DesignSystem.Colors.accent

    /// Resolve the full Mountain record from our pool so we can pass it to ProAnalysis / start mission.
    /// Returns nil for free-form goals not linked to a DB peak — those goals can still be viewed,
    /// edited and deleted, just not used to launch a recording session.
    private var resolvedMountain: Mountain? {
        guard let id = goal.mountainId else { return nil }
        let pool = discoveryVM.recommendedPeaks + discoveryVM.suggestedRoutes
        return pool.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        mapHero
                        statsRow
                        if !goal.notes.isEmpty { notesCard }
                        actionButtons
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle(goal.mountainName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { onEdit() } label: { Label("Edit Goal", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(); dismiss() } label: {
                            Label("Delete Goal", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showProAnalysis) {
                if let m = resolvedMountain {
                    MountainProAnalysisSheet(mountain: m)
                        .presentationDetents([.large])
                        .preferredColorScheme(.dark)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var mapHero: some View {
        if let coord = goal.coordinate {
            let region = MKCoordinateRegion(center: coord,
                                            latitudinalMeters: 8000,
                                            longitudinalMeters: 8000)
            ZStack(alignment: .bottomLeading) {
                Map(initialPosition: .region(region), interactionModes: []) {
                    Annotation(goal.mountainName, coordinate: coord) {
                        ZStack {
                            Circle().fill(accent).frame(width: 36, height: 36)
                            Image(systemName: "mountain.2.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .black))
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                )
            }
        } else {
            // Fallback header when no coordinates
            HStack {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(accent)
                VStack(alignment: .leading) {
                    Text(goal.mountainName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("\(goal.elevationM) m")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        }
    }

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: "\(goal.elevationM)", unit: "m", label: "Elevation")
            Divider().frame(height: 30)
            if let days = goal.daysUntilTarget {
                if days < 0 {
                    stat(value: "\(-days)", unit: "d", label: "Past due", tint: .red)
                } else {
                    stat(value: "\(days)", unit: "d", label: "To go", tint: accent)
                }
            } else {
                stat(value: "—", unit: "", label: "No deadline")
            }
            Divider().frame(height: 30)
            if let snap = goal.readinessSnapshot {
                stat(value: "\(snap)", unit: "%", label: "Was ready")
            } else if let r = appState.readiness {
                stat(value: "\(Int(r.totalScore))", unit: "%", label: "Ready now", tint: accent)
            } else {
                stat(value: "—", unit: "", label: "Readiness")
            }
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }

    private func stat(value: String, unit: String, label: String, tint: Color = .primary) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var notesCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text(goal.notes)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let m = resolvedMountain {
                // Primary CTA — start a mission targeting this peak
                Button {
                    onStartMission(m)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Mission")
                    }
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                }

                // Secondary — pro analysis
                Button { showProAnalysis = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                        Text("Pro Analysis")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.sun.fill")
                            Image(systemName: "exclamationmark.triangle.fill")
                            Image(systemName: "triangle.fill")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                            .stroke(accent.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                }
            }
        }
    }
}
