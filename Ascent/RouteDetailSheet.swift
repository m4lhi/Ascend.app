import SwiftUI
import MapKit
import CoreLocation
import Supabase

// =========================================
// === DATEI: RouteDetailSheet.swift ===
// === Full Route Detail View (Komoot-style) ===
// =========================================

struct RouteDetailSheet: View {
    let route: SavedRoute
    @ObservedObject var routeManager: RouteSavingManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var mountains: [Mountain] = []
    @State private var isLoading = false
    @State private var showEditSheet = false
    @State private var showSaveToFolderSheet = false
    @State private var showShareSheet = false
    @State private var selectedMountain: Mountain?
    @State private var userRating: Int

    private let accent = DesignSystem.Colors.accent

    init(route: SavedRoute, routeManager: RouteSavingManager) {
        self.route = route
        self.routeManager = routeManager
        _userRating = State(initialValue: route.rating ?? 0)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.945, green: 0.945, blue: 0.96).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Map Header
                        routeMapHeader
                            .frame(height: 260)

                        VStack(alignment: .leading, spacing: 20) {
                            // Title & Meta
                            routeTitleSection

                            // Stats Row
                            routeStatsRow

                            // Quick Actions
                            quickActionsRow

                            // Elevation Profile
                            if !mountains.isEmpty {
                                elevationSection
                            }

                            // Rating
                            ratingSection

                            // Tags
                            if !route.tags.isEmpty {
                                tagsSection
                            }

                            // Mountains in Route
                            if !mountains.isEmpty {
                                mountainsSection
                            }

                            // Description
                            if !route.description.isEmpty {
                                descriptionSection
                            }

                            // Danger Zone
                            dangerZone

                            Spacer(minLength: 40)
                        }
                        .padding(20)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showEditSheet = true } label: {
                            Label("Edit Route", systemImage: "pencil")
                        }
                        Button { showSaveToFolderSheet = true } label: {
                            Label("Add to Folder", systemImage: "folder.badge.plus")
                        }
                        Button { showShareSheet = true } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button {
                            Task { await routeManager.toggleCompleted(route: route) }
                        } label: {
                            Label(route.isCompleted ? "Mark Incomplete" : "Mark Completed",
                                  systemImage: route.isCompleted ? "xmark.circle" : "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(.body, design: .rounded).weight(.bold))
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.bold))
                }
            }
            .task { await fetchMountains() }
            .sheet(isPresented: $showEditSheet) {
                EditRouteSheet(route: route, routeManager: routeManager)
            }
            .sheet(isPresented: $showSaveToFolderSheet) {
                SaveRouteToFolderSheet(route: route, routeManager: routeManager)
            }
        }
    }

    // MARK: - Map Header

    @ViewBuilder
    var routeMapHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Map {
                if mountains.count >= 2 {
                    let coords = mountains.compactMap { m -> CLLocationCoordinate2D? in
                        guard let lat = m.latitude, let lon = m.longitude else { return nil }
                        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                    MapPolyline(coordinates: coords)
                        .stroke(accent, lineWidth: 4)
                }

                ForEach(Array(mountains.enumerated()), id: \.element.id) { index, mountain in
                    if let lat = mountain.latitude, let lon = mountain.longitude {
                        Annotation("\(index + 1)", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            ZStack {
                                Circle().fill(accent).frame(width: 28, height: 28)
                                Text("\(index + 1)")
                                    .font(.app(size: 12, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .flat))
            .disabled(true)

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)

            // Sport type badge
            HStack(spacing: 8) {
                Image(systemName: route.sportIcon)
                    .font(.app(size: 14, weight: .bold))
                Text(route.sportType.label.uppercased())
                    .font(.app(size: 11, weight: .black))
                    .tracking(1.5)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(Capsule())
            .padding(16)

            // Completed badge
            if route.isCompleted {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("COMPLETED")
                                .font(.app(size: 10, weight: .black))
                                .tracking(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .clipShape(Capsule())
                        .padding(16)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Title Section

    @ViewBuilder
    var routeTitleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(route.name)
                .font(.app(size: 28, weight: .bold))

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: route.visibility.icon)
                        .font(.app(size: 11))
                    Text(route.visibility.label)
                        .font(.app(size: 12, weight: .semibold))
                }
                .foregroundColor(.secondary)

                Text(route.difficulty.uppercased())
                    .font(.app(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(difficultyColor)
                    .clipShape(Capsule())

                Text(route.createdAt, style: .date)
                    .font(.app(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    var routeStatsRow: some View {
        HStack(spacing: 0) {
            routeStat(icon: "point.topleft.down.to.point.bottomright.curvepath",
                      value: String(format: "%.1f km", route.totalDistanceKm), label: "Distance")
            routeStat(icon: "arrow.up.right",
                      value: "+\(route.totalElevationGain)m", label: "Elevation")
            routeStat(icon: "clock",
                      value: route.durationFormatted, label: "Duration")
            routeStat(icon: "mountain.2.fill",
                      value: "\(route.mountainIds.count)", label: "Peaks")
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    func routeStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.app(size: 18))
                .foregroundColor(accent)
            Text(value)
                .font(.app(size: 16, weight: .bold))
            Text(label)
                .font(.app(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Actions

    @ViewBuilder
    var quickActionsRow: some View {
        HStack(spacing: 12) {
            quickAction(icon: "folder.badge.plus", label: "Save to Folder") {
                showSaveToFolderSheet = true
            }
            quickAction(icon: "square.and.arrow.up", label: "Share") {
                showShareSheet = true
            }
            quickAction(icon: route.isCompleted ? "checkmark.circle.fill" : "circle",
                        label: route.isCompleted ? "Done" : "Mark Done",
                        active: route.isCompleted) {
                Task { await routeManager.toggleCompleted(route: route) }
            }
        }
    }

    func quickAction(icon: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.app(size: 20, weight: .medium))
                    .foregroundColor(active ? .green : accent)
                Text(label)
                    .font(.app(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Elevation Section

    @ViewBuilder
    var elevationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Elevation Profile")
                .font(.app(size: 16, weight: .bold))

            RouteElevationProfile(mountains: mountains, accentColor: accent)
                .frame(height: 70)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }

    // MARK: - Rating

    @ViewBuilder
    var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Rating")
                .font(.app(size: 16, weight: .bold))

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        userRating = star
                        Task { await routeManager.setRating(route: route, rating: star) }
                        HapticManager.shared.light()
                    } label: {
                        Image(systemName: star <= userRating ? "star.fill" : "star")
                            .font(.app(size: 24))
                            .foregroundColor(star <= userRating ? .yellow : .gray.opacity(0.3))
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }

    // MARK: - Tags

    @ViewBuilder
    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.app(size: 16, weight: .bold))

            FlowLayout(spacing: 8) {
                ForEach(route.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.app(size: 12, weight: .semibold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Mountains

    @ViewBuilder
    var mountainsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Peaks on this Route")
                .font(.app(size: 16, weight: .bold))

            ForEach(Array(mountains.enumerated()), id: \.element.id) { index, mountain in
                Button { selectedMountain = mountain } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(accent).frame(width: 32, height: 32)
                            Text("\(index + 1)")
                                .font(.app(size: 14, weight: .black))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mountain.name)
                                .font(.app(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            Text("\(mountain.elevation)m \u{00B7} \(mountain.region)")
                                .font(.app(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(mountain.difficulty.rawValue)
                            .font(.app(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(mountain.difficulty.color)
                            .clipShape(Capsule())

                        Image(systemName: "chevron.right")
                            .font(.app(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Description

    @ViewBuilder
    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.app(size: 16, weight: .bold))

            Text(route.description)
                .font(.app(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }

    // MARK: - Danger Zone

    @ViewBuilder
    var dangerZone: some View {
        Button {
            Task {
                await routeManager.deleteRoute(id: route.id)
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Route")
            }
            .font(.app(size: 14, weight: .semibold))
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 10)
    }

    // MARK: - Helpers

    private var difficultyColor: Color {
        switch route.difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .blue
        case "hard": return .orange
        case "extreme": return .red
        case "expert": return .purple
        default: return .gray
        }
    }

    private func fetchMountains() async {
        guard !route.mountainIds.isEmpty else { return }
        isLoading = true
        do {
            let idStrings = route.mountainIds.map { $0.uuidString }
            let results: [Mountain] = try await supabase
                .from("mountains")
                .select("*, routes:mountain_routes(*)")
                .in("id", values: idStrings)
                .execute()
                .value
            // Preserve route order
            self.mountains = route.mountainIds.compactMap { id in
                results.first { $0.id == id }
            }
        } catch {
            print("❌ Fetch route mountains error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Edit Route Sheet
struct EditRouteSheet: View {
    let route: SavedRoute
    @ObservedObject var routeManager: RouteSavingManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var description: String
    @State private var visibility: RouteVisibility
    @State private var sportType: SportType
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var isSaving = false

    init(route: SavedRoute, routeManager: RouteSavingManager) {
        self.route = route
        self.routeManager = routeManager
        _name = State(initialValue: route.name)
        _description = State(initialValue: route.description)
        _visibility = State(initialValue: route.visibility)
        _sportType = State(initialValue: route.sportType)
        _tags = State(initialValue: route.tags)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Name
                    fieldSection(title: "NAME") {
                        TextField("Route name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description
                    fieldSection(title: "DESCRIPTION") {
                        TextField("Describe your route...", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    // Sport Type
                    fieldSection(title: "SPORT TYPE") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(SportType.allCases, id: \.self) { sport in
                                    Button {
                                        sportType = sport
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: sport.icon)
                                            Text(sport.label)
                                        }
                                        .font(.app(size: 13, weight: .semibold))
                                        .foregroundColor(sportType == sport ? .white : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(sportType == sport ? DesignSystem.Colors.accent : Color(.systemGray6))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    // Visibility
                    fieldSection(title: "VISIBILITY") {
                        HStack(spacing: 8) {
                            ForEach(RouteVisibility.allCases, id: \.self) { vis in
                                Button {
                                    visibility = vis
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: vis.icon)
                                        Text(vis.label)
                                    }
                                    .font(.app(size: 13, weight: .semibold))
                                    .foregroundColor(visibility == vis ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(visibility == vis ? DesignSystem.Colors.accent : Color(.systemGray6))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Tags
                    fieldSection(title: "TAGS") {
                        VStack(alignment: .leading, spacing: 8) {
                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                        Button { tags.removeAll { $0 == tag } } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.app(size: 12))
                                        }
                                    }
                                    .font(.app(size: 12, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(DesignSystem.Colors.accent.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }

                            HStack {
                                TextField("Add tag...", text: $newTag)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    let trimmed = newTag.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty && !tags.contains(trimmed) {
                                        tags.append(trimmed)
                                        newTag = ""
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.app(size: 24))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                        }
                    }

                    // Save Button
                    Button(action: save) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(name.isEmpty ? DesignSystem.Colors.accent.opacity(0.3) : DesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(name.isEmpty || isSaving)
                }
                .padding(20)
            }
            .navigationTitle("Edit Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
        }
    }

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.app(size: 11, weight: .black))
                .foregroundColor(.gray)
                .tracking(2)
            content()
        }
    }

    private func save() {
        isSaving = true
        var updated = route
        updated.name = name
        updated.description = description
        updated.visibility = visibility
        updated.sportType = sportType
        updated.tags = tags
        updated.updatedAt = Date()

        Task {
            let success = await routeManager.updateRoute(updated)
            if success { dismiss() }
            isSaving = false
        }
    }
}

// MARK: - Save Route To Folder Sheet
struct SaveRouteToFolderSheet: View {
    let route: SavedRoute
    @ObservedObject var routeManager: RouteSavingManager
    @Environment(\.dismiss) var dismiss
    @State private var showCreateFolder = false

    var body: some View {
        NavigationView {
            Group {
                if routeManager.myFolders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.app(size: 44))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No Folders yet")
                            .font(.app(.headline))
                        Text("Create your first folder to organize routes.")
                            .font(.app(.subheadline))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button { showCreateFolder = true } label: {
                            Text("Create Folder")
                                .font(.app(.body)).fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32).padding(.vertical, 14)
                                .background(DesignSystem.Colors.accent)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(40)
                } else {
                    List {
                        ForEach(routeManager.myFolders) { folder in
                            Button {
                                Task {
                                    let success = await routeManager.addRouteToFolder(routeId: route.id, folderId: folder.id)
                                    if success {
                                        HapticManager.shared.success()
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: folder.icon)
                                        .font(.app(size: 20))
                                        .foregroundColor(folder.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(folder.accentColor.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.name)
                                            .font(.app(.headline))
                                            .foregroundColor(.primary)
                                        HStack(spacing: 8) {
                                            if folder.isShared {
                                                Image(systemName: "person.2.fill")
                                                    .font(.app(size: 10))
                                                    .foregroundColor(.blue)
                                            }
                                            Text(folder.description)
                                                .font(.app(.caption))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Save to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: { Text("Cancel").fontWeight(.medium) }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showCreateFolder = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await routeManager.fetchMyFolders() }
            .sheet(isPresented: $showCreateFolder) {
                CreateFolderSheet(routeManager: routeManager)
            }
        }
    }
}
