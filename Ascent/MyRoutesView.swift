import SwiftUI
import MapKit
import CoreLocation

// =========================================
// === DATEI: MyRoutesView.swift ===
// === Komoot-style Route Library ===
// =========================================

struct MyRoutesView: View {
    @StateObject private var routeManager = RouteSavingManager.shared
    @EnvironmentObject var appState: AppState

    @State private var selectedTab: RouteTab = .routes
    @State private var selectedRoute: SavedRoute?
    @State private var selectedFolder: RouteFolder?
    @State private var showCreateFolder = false
    @State private var searchText = ""
    @State private var selectedSportFilter: SportType?
    @State private var sortMode: RouteSortMode = .newest

    enum RouteTab: String, CaseIterable {
        case routes = "Routes"
        case folders = "Folders"
        case shared = "Shared"
    }

    enum RouteSortMode: String, CaseIterable {
        case newest = "Newest"
        case distance = "Distance"
        case elevation = "Elevation"
        case name = "A-Z"
    }

    private let accent = DesignSystem.Colors.accent

    var filteredRoutes: [SavedRoute] {
        var routes = routeManager.myRoutes
        if !searchText.isEmpty {
            routes = routes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.description.localizedCaseInsensitiveContains(searchText)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if let sport = selectedSportFilter {
            routes = routes.filter { $0.sportType == sport }
        }
        switch sortMode {
        case .newest:    routes.sort { $0.updatedAt > $1.updatedAt }
        case .distance:  routes.sort { $0.totalDistanceKm > $1.totalDistanceKm }
        case .elevation: routes.sort { $0.totalElevationGain > $1.totalElevationGain }
        case .name:      routes.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
        return routes
    }

    var body: some View {
        ZStack {
            Color(red: 0.945, green: 0.945, blue: 0.96).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    routeLibraryHeader

                    // Stats Summary
                    statsSummary
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Tab Selector
                    tabSelector
                        .padding(.top, 20)

                    // Content
                    switch selectedTab {
                    case .routes:
                        routesContent
                    case .folders:
                        foldersContent
                    case .shared:
                        sharedContent
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .task { await routeManager.fetchAll() }
        .sheet(item: $selectedRoute) { route in
            RouteDetailSheet(route: route, routeManager: routeManager)
                .presentationDetents([.large])
                .preferredColorScheme(.light)
        }
        .sheet(item: $selectedFolder) { folder in
            FolderDetailSheet(folder: folder, routeManager: routeManager)
                .presentationDetents([.large])
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderSheet(routeManager: routeManager)
        }
    }

    // MARK: - Header

    @ViewBuilder
    var routeLibraryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("My Routes")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Your personal route library")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Stats Summary

    @ViewBuilder
    var statsSummary: some View {
        let stats = routeManager.totalRouteStats
        HStack(spacing: 0) {
            miniStat(value: "\(stats.count)", label: "Routes", icon: "map")
            miniStat(value: String(format: "%.0f km", stats.distance), label: "Total", icon: "point.topleft.down.to.point.bottomright.curvepath")
            miniStat(value: "+\(stats.elevation)m", label: "Elevation", icon: "arrow.up.right")
            miniStat(value: "\(routeManager.myRoutes.filter { $0.isCompleted }.count)", label: "Done", icon: "checkmark.seal.fill")
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    func miniStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(accent)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Selector

    @ViewBuilder
    var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(RouteTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? accent : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    // MARK: - Routes Content

    @ViewBuilder
    var routesContent: some View {
        VStack(spacing: 16) {
            // Search + Sort
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    TextField("Search routes...", text: $searchText)
                        .font(.system(size: 14, design: .rounded))
                }
                .padding(10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)

                Menu {
                    ForEach(RouteSortMode.allCases, id: \.self) { mode in
                        Button {
                            sortMode = mode
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                if sortMode == mode { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                }
            }
            .padding(.horizontal, 20)

            // Sport Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    sportFilterChip(label: "All", icon: "infinity", sport: nil)
                    ForEach(SportType.allCases, id: \.self) { sport in
                        sportFilterChip(label: sport.label, icon: sport.icon, sport: sport)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Route Cards
            if filteredRoutes.isEmpty {
                emptyRoutesState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredRoutes) { route in
                        EnhancedRouteCard(route: route) {
                            selectedRoute = route
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }

    func sportFilterChip(label: String, icon: String, sport: SportType?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedSportFilter = sport }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(selectedSportFilter == sport ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedSportFilter == sport ? accent : Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        }
    }

    var emptyRoutesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.25))
            Text("No routes yet")
                .font(.system(.headline, design: .rounded))
            Text("Create a route in the Explore tab to get started.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Folders Content

    @ViewBuilder
    var foldersContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(routeManager.myFolders.count) Folders")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Button { showCreateFolder = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New Folder")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                }
            }
            .padding(.horizontal, 20)

            if routeManager.myFolders.isEmpty {
                emptyFoldersState
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(routeManager.myFolders) { folder in
                        FolderCard(folder: folder) {
                            selectedFolder = folder
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }

    var emptyFoldersState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.25))
            Text("No folders yet")
                .font(.system(.headline, design: .rounded))
            Text("Create folders to organize and share your routes.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button { showCreateFolder = true } label: {
                Text("Create Folder")
                    .font(.system(.body, design: .rounded)).fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .background(accent)
                    .clipShape(Capsule())
            }
        }
        .padding(40)
    }

    // MARK: - Shared Content

    @ViewBuilder
    var sharedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if routeManager.sharedFolders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.25))
                    Text("No shared folders")
                        .font(.system(.headline, design: .rounded))
                    Text("When someone shares a route folder with you, it will appear here.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(routeManager.sharedFolders) { folder in
                        FolderCard(folder: folder, isShared: true) {
                            selectedFolder = folder
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Enhanced Route Card

struct EnhancedRouteCard: View {
    let route: SavedRoute
    let onTap: () -> Void

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Mini Map Preview
                miniMapPreview
                    .frame(height: 120)
                    .clipped()

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(route.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        if route.isCompleted {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: route.sportIcon)
                                .font(.system(size: 10))
                            Text(route.sportType.label)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.secondary)

                        Text(route.difficulty.capitalized)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(difficultyColor)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 16) {
                        statLabel(icon: "point.topleft.down.to.point.bottomright.curvepath", value: String(format: "%.1fkm", route.totalDistanceKm))
                        statLabel(icon: "arrow.up.right", value: "+\(route.totalElevationGain)m")
                        statLabel(icon: "clock", value: route.durationFormatted)
                        statLabel(icon: "mountain.2.fill", value: "\(route.mountainIds.count)")
                    }

                    if route.rating != nil && route.rating! > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= (route.rating ?? 0) ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(star <= (route.rating ?? 0) ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(14)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var miniMapPreview: some View {
        // Use a gradient placeholder with route info overlay
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.3), accent.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Route visualization
            HStack(spacing: 0) {
                ForEach(0..<min(route.mountainIds.count, 5), id: \.self) { i in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                        if i < min(route.mountainIds.count, 5) - 1 {
                            Rectangle()
                                .fill(accent.opacity(0.4))
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)

            // Visibility badge
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: route.visibility.icon)
                            .font(.system(size: 9))
                        Text(route.visibility.label)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(8)
                }
                Spacer()
            }
        }
    }

    func statLabel(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

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
}

// MARK: - Folder Card

struct FolderCard: View {
    let folder: RouteFolder
    var isShared: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [folder.accentColor.opacity(0.6), folder.accentColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)

                    Image(systemName: folder.icon)
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.7))

                    if isShared || folder.isShared {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(.ultraThinMaterial.opacity(0.6))
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(folder.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !folder.description.isEmpty {
                        Text(folder.description)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder Detail Sheet

struct FolderDetailSheet: View {
    let folder: RouteFolder
    @ObservedObject var routeManager: RouteSavingManager
    @Environment(\.dismiss) var dismiss

    @State private var routes: [SavedRoute] = []
    @State private var members: [RouteFolderMember] = []
    @State private var isLoading = false
    @State private var selectedRoute: SavedRoute?
    @State private var showShareSheet = false
    @State private var showEditFolder = false

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.945, green: 0.945, blue: 0.96).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Folder Header
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(
                                colors: [folder.accentColor.opacity(0.7), folder.accentColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 200)

                            Image(systemName: folder.icon)
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 60)

                            VStack(alignment: .leading, spacing: 6) {
                                if folder.isShared {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 11))
                                        Text("SHARED FOLDER")
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                            .tracking(1)
                                    }
                                    .foregroundColor(.white.opacity(0.8))
                                }

                                Text(folder.name)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                if !folder.description.isEmpty {
                                    Text(folder.description)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(2)
                                }

                                HStack(spacing: 16) {
                                    Text("\(routes.count) routes")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    if !members.isEmpty {
                                        Text("\(members.count + 1) members")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    }
                                }
                                .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(20)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            // Action Buttons
                            HStack(spacing: 12) {
                                Button { showShareSheet = true } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.badge.plus")
                                        Text("Invite")
                                    }
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button { showEditFolder = true } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                        Text("Edit")
                                    }
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            // Members Preview
                            if !members.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Members")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: -8) {
                                            ForEach(members.prefix(8)) { member in
                                                Circle()
                                                    .fill(accent.opacity(0.3))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Text(member.role.prefix(1).uppercased())
                                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                                            .foregroundColor(accent)
                                                    )
                                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                            }
                                            if members.count > 8 {
                                                Circle()
                                                    .fill(Color(.systemGray5))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Text("+\(members.count - 8)")
                                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                                            .foregroundColor(.secondary)
                                                    )
                                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                            }
                                        }
                                    }
                                }
                            }

                            // Routes
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Routes")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))

                                if isLoading {
                                    ProgressView().frame(maxWidth: .infinity).padding(40)
                                } else if routes.isEmpty {
                                    VStack(spacing: 10) {
                                        Image(systemName: "map")
                                            .font(.system(size: 36))
                                            .foregroundColor(.gray.opacity(0.3))
                                        Text("No routes in this folder yet")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(32)
                                } else {
                                    ForEach(routes) { route in
                                        EnhancedRouteCard(route: route) {
                                            selectedRoute = route
                                        }
                                    }
                                }
                            }

                            // Delete Folder
                            Button {
                                Task {
                                    await routeManager.deleteFolder(id: folder.id)
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Folder")
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.top, 20)

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
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.bold))
                }
            }
            .task {
                isLoading = true
                async let routesResult = routeManager.fetchRoutesForFolder(folderId: folder.id)
                async let membersResult = routeManager.fetchFolderMembers(folderId: folder.id)
                routes = await routesResult
                members = await membersResult
                isLoading = false
            }
            .sheet(item: $selectedRoute) { route in
                RouteDetailSheet(route: route, routeManager: routeManager)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareFolderSheet(folder: folder, routeManager: routeManager)
            }
        }
    }
}

// MARK: - Create Folder Sheet

struct CreateFolderSheet: View {
    @ObservedObject var routeManager: RouteSavingManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "#2680FF"
    @State private var selectedIcon = "folder.fill"
    @State private var isSaving = false

    private let colorOptions = ["#2680FF", "#FF6B35", "#4CAF50", "#9C27B0", "#FF9800", "#E91E63", "#00BCD4", "#795548"]
    private let iconOptions = ["folder.fill", "map.fill", "mountain.2.fill", "star.fill", "heart.fill", "flag.fill", "bookmark.fill", "trophy.fill"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [(Color(hex: selectedColor) ?? .blue).opacity(0.6),
                                             (Color(hex: selectedColor) ?? .blue).opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 140)

                        VStack(spacing: 8) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                            Text(name.isEmpty ? "Folder Name" : name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(2)
                        TextField("e.g. Summer Alpine Routes", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(2)
                        TextField("Optional description...", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    // Color Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COLOR")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(2)
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(Color(hex: color) ?? .blue)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                                .shadow(color: .black.opacity(0.3), radius: 2)
                                        )
                                }
                            }
                        }
                    }

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ICON")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(2)
                        HStack(spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? (Color(hex: selectedColor) ?? .blue) : Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    Spacer()

                    Button(action: save) {
                        if isSaving { ProgressView().tint(.white) }
                        else { Text("Create Folder") }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(name.isEmpty ? DesignSystem.Colors.accent.opacity(0.3) : DesignSystem.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(name.isEmpty || isSaving)
                }
                .padding(20)
            }
            .navigationTitle("New Folder")
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

    private func save() {
        isSaving = true
        Task {
            let _ = await routeManager.createFolder(
                name: name,
                description: description,
                color: selectedColor,
                icon: selectedIcon
            )
            dismiss()
            isSaving = false
        }
    }
}

// MARK: - Share Folder Sheet

struct ShareFolderSheet: View {
    let folder: RouteFolder
    @ObservedObject var routeManager: RouteSavingManager
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var searchResults: [ShareableUser] = []
    @State private var isSearching = false
    @State private var currentMembers: [RouteFolderMember] = []
    @State private var selectedRole = "viewer"
    @State private var searchTask: Task<Void, Never>?

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search by username or handle...", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Role Selector
                HStack(spacing: 8) {
                    ForEach(["viewer", "editor", "admin"], id: \.self) { role in
                        Button {
                            selectedRole = role
                        } label: {
                            Text(role.capitalized)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(selectedRole == role ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedRole == role ? accent : Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Search Results
                if !searchText.isEmpty {
                    if isSearching {
                        ProgressView().padding(20)
                    } else if searchResults.isEmpty {
                        Text("No users found")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(20)
                    } else {
                        List {
                            ForEach(searchResults) { user in
                                Button {
                                    Task {
                                        let success = await routeManager.addMemberToFolder(
                                            folderId: folder.id,
                                            userId: user.id,
                                            role: selectedRole
                                        )
                                        if success {
                                            HapticManager.shared.success()
                                            currentMembers = await routeManager.fetchFolderMembers(folderId: folder.id)
                                            searchText = ""
                                            searchResults = []
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(accent.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Text(String(user.username.prefix(1)).uppercased())
                                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                                    .foregroundColor(accent)
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.username)
                                                .font(.system(.headline, design: .rounded))
                                                .foregroundColor(.primary)
                                            Text("@\(user.handle)")
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "person.badge.plus")
                                            .foregroundColor(accent)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }

                // Current Members
                if !currentMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Members (\(currentMembers.count))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        List {
                            ForEach(currentMembers) { member in
                                HStack {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        )
                                    VStack(alignment: .leading) {
                                        Text(member.user_id.uuidString.prefix(8) + "...")
                                            .font(.system(.subheadline, design: .rounded))
                                        Text(member.role.capitalized)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button {
                                        Task {
                                            await routeManager.removeMemberFromFolder(folderId: folder.id, userId: member.user_id)
                                            currentMembers = await routeManager.fetchFolderMembers(folderId: folder.id)
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    .padding(.top, 16)
                }

                Spacer()
            }
            .navigationTitle("Share Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.bold))
                }
            }
            .task {
                currentMembers = await routeManager.fetchFolderMembers(folderId: folder.id)
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    searchResults = await routeManager.searchUsersForSharing(query: newValue)
                    isSearching = false
                }
            }
        }
    }
}
