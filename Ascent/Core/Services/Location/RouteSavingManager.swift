import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: RouteSavingManager.swift ===
// === Komoot-inspired Route Saving System ===
// =========================================

@MainActor
class RouteSavingManager: ObservableObject {
    static let shared = RouteSavingManager()

    @Published var myRoutes: [SavedRoute] = []
    @Published var myFolders: [RouteFolder] = []
    @Published var sharedFolders: [RouteFolder] = []
    @Published var isLoading = false

    // MARK: - Routes CRUD

    func fetchMyRoutes() async {
        isLoading = true
        do {
            let userId = try await supabase.auth.session.user.id
            let results: [SavedRoute] = try await supabase
                .from("saved_routes")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            self.myRoutes = results
        } catch {
            print("❌ Fetch routes error: \(error)")
        }
        isLoading = false
    }

    func saveRoute(_ route: SavedRoute) async -> Bool {
        do {
            var routeToSave = route
            if routeToSave.user_id == nil {
                routeToSave.user_id = try await supabase.auth.session.user.id
            }
            try await supabase.from("saved_routes").insert(routeToSave).execute()
            await fetchMyRoutes()
            return true
        } catch {
            print("❌ Save route error: \(error)")
            return false
        }
    }

    func updateRoute(_ route: SavedRoute) async -> Bool {
        do {
            try await supabase.from("saved_routes")
                .update(route)
                .eq("id", value: route.id)
                .execute()
            await fetchMyRoutes()
            return true
        } catch {
            print("❌ Update route error: \(error)")
            return false
        }
    }

    func deleteRoute(id: UUID) async {
        do {
            try await supabase.from("saved_routes").delete().eq("id", value: id).execute()
            myRoutes.removeAll { $0.id == id }
        } catch {
            print("❌ Delete route error: \(error)")
        }
    }

    func toggleCompleted(route: SavedRoute) async {
        var updated = route
        updated.isCompleted.toggle()
        updated.updatedAt = Date()
        _ = await updateRoute(updated)
    }

    func setRating(route: SavedRoute, rating: Int) async {
        var updated = route
        updated.rating = rating
        updated.updatedAt = Date()
        _ = await updateRoute(updated)
    }

    // MARK: - Folders CRUD

    func fetchMyFolders() async {
        do {
            let userId = try await supabase.auth.session.user.id
            let results: [RouteFolder] = try await supabase
                .from("route_folders")
                .select()
                .eq("owner_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            self.myFolders = results
        } catch {
            print("❌ Fetch folders error: \(error)")
        }
    }

    func fetchSharedFolders() async {
        do {
            let userId = try await supabase.auth.session.user.id
            let memberRows: [RouteFolderMember] = try await supabase
                .from("route_folder_members")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let folderIds = memberRows.map { $0.folder_id.uuidString }
            guard !folderIds.isEmpty else { self.sharedFolders = []; return }
            let results: [RouteFolder] = try await supabase
                .from("route_folders")
                .select()
                .in("id", values: folderIds)
                .order("updated_at", ascending: false)
                .execute()
                .value
            self.sharedFolders = results
        } catch {
            print("❌ Fetch shared folders error: \(error)")
        }
    }

    func createFolder(name: String, description: String, color: String = "#2680FF", icon: String = "folder.fill") async -> RouteFolder? {
        do {
            let userId = try await supabase.auth.session.user.id
            let folder = RouteFolder(
                owner_id: userId,
                name: name,
                description: description,
                color: color,
                icon: icon
            )
            try await supabase.from("route_folders").insert(folder).execute()
            await fetchMyFolders()
            return folder
        } catch {
            print("❌ Create folder error: \(error)")
            return nil
        }
    }

    func updateFolder(_ folder: RouteFolder) async -> Bool {
        do {
            try await supabase.from("route_folders")
                .update(folder)
                .eq("id", value: folder.id)
                .execute()
            await fetchMyFolders()
            return true
        } catch {
            print("❌ Update folder error: \(error)")
            return false
        }
    }

    func deleteFolder(id: UUID) async {
        do {
            try await supabase.from("route_folders").delete().eq("id", value: id).execute()
            myFolders.removeAll { $0.id == id }
        } catch {
            print("❌ Delete folder error: \(error)")
        }
    }

    // MARK: - Folder <-> Route Management

    func fetchRoutesForFolder(folderId: UUID) async -> [SavedRoute] {
        do {
            let junctions: [RouteFolderRoute] = try await supabase
                .from("route_folder_routes")
                .select()
                .eq("folder_id", value: folderId)
                .order("sort_order", ascending: true)
                .execute()
                .value
            let routeIds = junctions.map { $0.route_id.uuidString }
            guard !routeIds.isEmpty else { return [] }
            let routes: [SavedRoute] = try await supabase
                .from("saved_routes")
                .select()
                .in("id", values: routeIds)
                .execute()
                .value
            // Preserve folder sort order
            return junctions.compactMap { j in routes.first { $0.id == j.route_id } }
        } catch {
            print("❌ Fetch folder routes error: \(error)")
            return []
        }
    }

    private struct FolderRouteInsert: Codable {
        let folder_id: UUID
        let route_id: UUID
        let added_by: UUID
    }

    func addRouteToFolder(routeId: UUID, folderId: UUID) async -> Bool {
        do {
            let userId = try await supabase.auth.session.user.id
            let junction = FolderRouteInsert(folder_id: folderId, route_id: routeId, added_by: userId)
            try await supabase.from("route_folder_routes").insert(junction).execute()
            return true
        } catch {
            print("❌ Add route to folder error: \(error)")
            return false
        }
    }

    func removeRouteFromFolder(routeId: UUID, folderId: UUID) async {
        do {
            try await supabase.from("route_folder_routes")
                .delete()
                .eq("folder_id", value: folderId)
                .eq("route_id", value: routeId)
                .execute()
        } catch {
            print("❌ Remove route from folder error: \(error)")
        }
    }

    // MARK: - Sharing

    func searchUsersForSharing(query: String) async -> [ShareableUser] {
        do {
            let results: [ShareableUser] = try await supabase
                .rpc("search_users_for_sharing", params: ["search_term": query])
                .execute()
                .value
            return results
        } catch {
            print("❌ Search users error: \(error)")
            return []
        }
    }

    private struct FolderMemberInsert: Codable {
        let folder_id: UUID
        let user_id: UUID
        let role: String
        let invited_by: UUID
    }

    private struct VisibilityUpdate: Codable {
        let visibility: String
    }

    func addMemberToFolder(folderId: UUID, userId: UUID, role: String = "viewer") async -> Bool {
        do {
            let invitedBy = try await supabase.auth.session.user.id
            let member = FolderMemberInsert(folder_id: folderId, user_id: userId, role: role, invited_by: invitedBy)
            try await supabase.from("route_folder_members").insert(member).execute()
            // Update folder visibility to shared
            try await supabase.from("route_folders")
                .update(VisibilityUpdate(visibility: "shared"))
                .eq("id", value: folderId)
                .execute()
            return true
        } catch {
            print("❌ Add member error: \(error)")
            return false
        }
    }

    func removeMemberFromFolder(folderId: UUID, userId: UUID) async {
        do {
            try await supabase.from("route_folder_members")
                .delete()
                .eq("folder_id", value: folderId)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("❌ Remove member error: \(error)")
        }
    }

    func fetchFolderMembers(folderId: UUID) async -> [RouteFolderMember] {
        do {
            let results: [RouteFolderMember] = try await supabase
                .from("route_folder_members")
                .select()
                .eq("folder_id", value: folderId)
                .execute()
                .value
            return results
        } catch {
            print("❌ Fetch members error: \(error)")
            return []
        }
    }

    private struct RoleUpdate: Codable {
        let role: String
    }

    func updateMemberRole(folderId: UUID, userId: UUID, newRole: String) async {
        do {
            try await supabase.from("route_folder_members")
                .update(RoleUpdate(role: newRole))
                .eq("folder_id", value: folderId)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("❌ Update member role error: \(error)")
        }
    }

    // MARK: - Convenience

    func fetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchMyRoutes() }
            group.addTask { await self.fetchMyFolders() }
            group.addTask { await self.fetchSharedFolders() }
        }
    }

    func routesNotInAnyFolder() -> [SavedRoute] {
        // This is a client-side filter; for large datasets, use a server-side query
        let folderRouteIds = Set<UUID>() // Would need to track this; simplified here
        return myRoutes.filter { !folderRouteIds.contains($0.id) }
    }

    var totalRouteStats: (distance: Double, elevation: Int, count: Int) {
        let dist = myRoutes.reduce(0.0) { $0 + $1.totalDistanceKm }
        let elev = myRoutes.reduce(0) { $0 + $1.totalElevationGain }
        return (dist, elev, myRoutes.count)
    }
}
