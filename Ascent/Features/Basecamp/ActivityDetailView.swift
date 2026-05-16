import SwiftUI
import MapKit

// =========================================
// === DATEI: ActivityDetailView.swift ===
// === TourDetailView — pastel editorial detail ===
// =========================================
//
// Rebuilt detail screen for a single Tour. Same MapKit + elevation
// profile + photo functionality as the old ActivityDetailView, now
// composed in the Tours/iteration-16 vocabulary:
//
//   - Top bar with close button on paperWarm (no .preferredColorScheme
//     forced dark, no dark map overlay).
//   - Editorial title (summit name) + relative date kicker.
//   - Bento 2×2 stats grid: duration, distance, elevation, XP.
//   - Story block (if storyComment present), surfaceWarm card.
//   - Route map (if routeCoordinates present) with start / summit
//     annotations and the route polyline in glacierDeep.
//   - Elevation profile (if routeLocations present), reusing the
//     existing ElevationProfileView component.
//   - Full-screen photo viewer below the map when photoURL is set.
//
// File name kept as ActivityDetailView.swift; the struct is
// TourDetailView so it can be referenced by TourCard.

struct TourDetailView: View {
    @Environment(\.dismiss) var dismiss
    let tour: Tour

    @State private var scrubDistance: Double? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: tour.date)
    }

    private var formattedDuration: String {
        Self.durationFormatter.string(from: tour.durationSeconds) ?? "0m"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.paperWarm.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {

                        titleBlock

                        statsBentoGrid

                        if let photoURL = tour.photoURL,
                           !photoURL.isEmpty,
                           let url = URL(string: photoURL) {
                            photoCard(url: url)
                        }

                        if !tour.storyComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            storyBlock
                        }

                        if !tour.routeCoordinates.isEmpty {
                            mapCard
                        }

                        if !tour.routeLocations.isEmpty {
                            elevationCard
                        }

                        Spacer().frame(height: DesignSystem.Spacing.xxl)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            }
        }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(tour.summitName)
                .font(DesignSystem.Typography.title1Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .fixedSize(horizontal: false, vertical: true)

            Text(formattedDate)
                .font(DesignSystem.Typography.kickerInter)
                .tracking(0.5)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
        }
    }

    private var statsBentoGrid: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                statCard(kicker: "Duration",
                         value: formattedDuration,
                         family: .sage)
                statCard(kicker: "Distance",
                         value: String(format: "%.1f km", tour.distanceKilometers),
                         family: .ice)
            }
            HStack(spacing: DesignSystem.Spacing.sm) {
                statCard(kicker: "Elevation gain",
                         value: "+\(tour.elevationGainMeters) m",
                         family: .sand)
                statCard(kicker: "XP",
                         value: "\(tour.xpGained)",
                         family: .sage)
            }
        }
    }

    private func statCard(kicker: String, value: String, family: PastelFamily) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kicker)
                .font(DesignSystem.Typography.kickerInter)
                .tracking(0.5)
                .foregroundStyle(family.ink.opacity(0.62))
            Text(value)
                .font(DesignSystem.Typography.title2Inter)
                .foregroundStyle(family.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pastelCard(family, applyForeground: false)
    }

    private var storyBlock: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Story")
                .font(DesignSystem.Typography.kickerInter)
                .tracking(0.5)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
            Text(tour.storyComment)
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(DesignSystem.Colors.surfaceWarm)
        )
    }

    private var mapCard: some View {
        Map {
            MapPolyline(coordinates: tour.routeCoordinates)
                .stroke(DesignSystem.Colors.glacierDeep, lineWidth: 4)

            if let first = tour.routeCoordinates.first {
                Annotation("Start", coordinate: first) {
                    Circle()
                        .fill(DesignSystem.Colors.meadow)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(DesignSystem.Colors.paperWarm, lineWidth: 2))
                }
            }

            if let last = tour.routeCoordinates.last, tour.routeCoordinates.count > 1 {
                Annotation("Summit", coordinate: last) {
                    Circle()
                        .fill(DesignSystem.Colors.alpenglow)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(DesignSystem.Colors.paperWarm, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private var elevationCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Elevation profile")
                .font(DesignSystem.Typography.kickerInter)
                .tracking(0.5)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)

            ElevationProfileView(
                routePoints: tour.routeLocations,
                compact: true,
                scrubDistanceOut: $scrubDistance
            )
            .frame(height: 80)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(DesignSystem.Colors.surfaceWarm)
        )
    }

    private func photoCard(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            default:
                Rectangle().fill(DesignSystem.Colors.surfaceWarm)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous))
    }
}
