import Foundation
import SwiftUI
import Combine
import Supabase
import MapKit
import CoreLocation

// =========================================
// === DATEI: CollectionsManager.swift ===
// === Kuratierte Tourensammlungen ===
// =========================================

// MARK: - Data Models

struct TourCollection: Identifiable, Codable, Hashable {
    let id: UUID
    let user_id: UUID
    var name: String
    var description: String
    var cover_image_url: String?
    var mountain_ids: [UUID]
    var visibility: String?
    var created_at: Date
    var updated_at: Date

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, description
        case cover_image_url, mountain_ids, visibility
        case created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        cover_image_url = try c.decodeIfPresent(String.self, forKey: .cover_image_url)
        mountain_ids = try c.decodeIfPresent([UUID].self, forKey: .mountain_ids) ?? []
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility)
        created_at = try c.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try c.decodeIfPresent(Date.self, forKey: .updated_at) ?? Date()
    }

    init(id: UUID = UUID(), user_id: UUID, name: String, description: String = "",
         cover_image_url: String? = nil, mountain_ids: [UUID] = [],
         visibility: String? = "private",
         created_at: Date = Date(), updated_at: Date = Date()) {
        self.id = id; self.user_id = user_id; self.name = name
        self.description = description; self.cover_image_url = cover_image_url
        self.mountain_ids = mountain_ids; self.visibility = visibility
        self.created_at = created_at; self.updated_at = updated_at
    }

    var isShared: Bool { visibility == "shared" || visibility == "public" }
}

struct CollectionMember: Identifiable, Codable {
    let id: UUID
    let collection_id: UUID
    let user_id: UUID
    let role: String
    let invited_by: UUID?
    let joined_at: Date

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        collection_id = try c.decode(UUID.self, forKey: .collection_id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "viewer"
        invited_by = try c.decodeIfPresent(UUID.self, forKey: .invited_by)
        joined_at = try c.decodeIfPresent(Date.self, forKey: .joined_at) ?? Date()
    }
}

struct CollectionWithMountains: Identifiable {
    let id: UUID
    let collection: TourCollection
    let mountains: [Mountain]
    var totalElevation: Int { mountains.reduce(0) { $0 + $1.elevation } }
    var peakCount: Int { mountains.count }
}

// MARK: - Manager

@MainActor
class CollectionsManager: ObservableObject {
    @Published var myCollections: [TourCollection] = [] {
        didSet { saveCache(myCollections, key: "myCollectionsCache") }
    }
    @Published var sharedCollections: [TourCollection] = [] {
        didSet { saveCache(sharedCollections, key: "sharedCollectionsCache") }
    }
    @Published var publicCollections: [TourCollection] = [] {
        didSet { saveCache(publicCollections, key: "publicCollectionsCache") }
    }
    @Published var isLoading = false

    init() {
        if let cached = loadCache(key: "myCollectionsCache", type: [TourCollection].self) { self.myCollections = cached }
        if let cached = loadCache(key: "sharedCollectionsCache", type: [TourCollection].self) { self.sharedCollections = cached }
        if let cached = loadCache(key: "publicCollectionsCache", type: [TourCollection].self) { self.publicCollections = cached }
    }

    private func saveCache<T: Encodable>(_ object: T, key: String) {
        if let data = try? JSONEncoder().encode(object) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadCache<T: Decodable>(key: String, type: T.Type) -> T? {
        if let data = UserDefaults.standard.data(forKey: key),
           let obj = try? JSONDecoder().decode(type, from: data) {
            return obj
        }
        return nil
    }

    // MARK: - Collections CRUD

    func fetchMyCollections() async {
        isLoading = true
        do {
            let userId = try await supabase.auth.session.user.id
            let results: [TourCollection] = try await supabase
                .from("collections")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            self.myCollections = results
        } catch {
            print("❌ Fetch collections error: \(error)")
        }
        isLoading = false
    }

    func fetchSharedCollections() async {
        do {
            let userId = try await supabase.auth.session.user.id
            let memberRows: [CollectionMember] = try await supabase
                .from("collection_members")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let collectionIds = memberRows.map { $0.collection_id.uuidString }
            guard !collectionIds.isEmpty else { self.sharedCollections = []; return }
            let results: [TourCollection] = try await supabase
                .from("collections")
                .select()
                .in("id", values: collectionIds)
                .order("updated_at", ascending: false)
                .execute()
                .value
            self.sharedCollections = results
        } catch {
            // Gracefully handle if collection_members table doesn't exist yet
            self.sharedCollections = []
        }
    }

    func fetchPublicCollections() async {
        do {
            let results: [TourCollection] = try await supabase
                .from("collections")
                .select()
                .order("created_at", ascending: false)
                .limit(30)
                .execute()
                .value
            self.publicCollections = results
        } catch {
            print("❌ Fetch public collections error: \(error)")
        }
    }

    func createCollection(name: String, description: String, mountainIds: [UUID]) async -> Bool {
        do {
            let userId = try await supabase.auth.session.user.id
            // Only send fields the DB definitely has — no visibility (might not exist yet)
            struct CollectionInsert: Codable {
                let user_id: UUID
                let name: String
                let description: String
                let mountain_ids: [UUID]
            }
            let insertModel = CollectionInsert(
                user_id: userId,
                name: name,
                description: description,
                mountain_ids: mountainIds
            )
            try await supabase.from("collections").insert(insertModel).execute()
            await fetchMyCollections()
            return true
        } catch {
            print("❌ Create collection error: \(error)")
            return false
        }
    }

    func addMountainToCollection(collectionId: UUID, mountainId: UUID) async {
        do {
            let currentCollection: TourCollection = try await supabase
                .from("collections")
                .select()
                .eq("id", value: collectionId)
                .single()
                .execute()
                .value
            
            var currentIds = currentCollection.mountain_ids
            guard !currentIds.contains(mountainId) else { return }
            currentIds.append(mountainId)
            
            struct UpdateMountains: Codable {
                let mountain_ids: [UUID]
            }
            let updateModel = UpdateMountains(mountain_ids: currentIds)
            try await supabase.from("collections")
                .update(updateModel)
                .eq("id", value: collectionId)
                .execute()
            
            if let index = myCollections.firstIndex(where: { $0.id == collectionId }) {
                await MainActor.run {
                    myCollections[index].mountain_ids = currentIds
                }
            }
            await fetchMyCollections()
        } catch {
            print("❌ Add to collection error: \(error)")
        }
    }

    func removeMountainFromCollection(collectionId: UUID, mountainId: UUID) async {
        do {
            let currentCollection: TourCollection = try await supabase
                .from("collections")
                .select()
                .eq("id", value: collectionId)
                .single()
                .execute()
                .value
            
            var currentIds = currentCollection.mountain_ids
            currentIds.removeAll { $0 == mountainId }
            
            struct UpdateMountains: Codable {
                let mountain_ids: [UUID]
            }
            let updateModel = UpdateMountains(mountain_ids: currentIds)
            try await supabase.from("collections")
                .update(updateModel)
                .eq("id", value: collectionId)
                .execute()
            
            if let index = myCollections.firstIndex(where: { $0.id == collectionId }) {
                await MainActor.run {
                    myCollections[index].mountain_ids = currentIds
                }
            }
            await fetchMyCollections()
        } catch {
            print("❌ Remove from collection error: \(error)")
        }
    }

    func deleteCollection(id: UUID) async {
        do {
            try await supabase.from("collections").delete().eq("id", value: id).execute()
            myCollections.removeAll { $0.id == id }
        } catch {
            print("❌ Delete collection error: \(error)")
        }
    }

    func fetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchMyCollections() }
            group.addTask { await self.fetchSharedCollections() }
            group.addTask { await self.fetchPublicCollections() }
        }
    }

    // MARK: - Members / Sharing

    func fetchMembers(collectionId: UUID) async -> [CollectionMember] {
        do {
            let results: [CollectionMember] = try await supabase
                .from("collection_members")
                .select()
                .eq("collection_id", value: collectionId)
                .execute()
                .value
            return results
        } catch {
            // Gracefully handle if collection_members table doesn't exist yet
            return []
        }
    }

    private struct MemberInsert: Codable {
        let collection_id: UUID
        let user_id: UUID
        let role: String
        let invited_by: UUID
    }

    private struct VisUpdate: Codable {
        let visibility: String
    }

    func addMember(collectionId: UUID, userId: UUID, role: String = "viewer") async -> Bool {
        do {
            let invitedBy = try await supabase.auth.session.user.id
            let member = MemberInsert(collection_id: collectionId, user_id: userId, role: role, invited_by: invitedBy)
            try await supabase.from("collection_members").insert(member).execute()
            // Try to update visibility — gracefully ignore if column doesn't exist yet
            _ = try? await supabase.from("collections")
                .update(VisUpdate(visibility: "shared"))
                .eq("id", value: collectionId)
                .execute()
            return true
        } catch {
            print("❌ Add collection member error: \(error)")
            return false
        }
    }

    func removeMember(collectionId: UUID, userId: UUID) async {
        do {
            try await supabase.from("collection_members")
                .delete()
                .eq("collection_id", value: collectionId)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("❌ Remove collection member error: \(error)")
        }
    }

    func searchUsers(query: String) async -> [ShareableUser] {
        do {
            let results: [ShareableUser] = try await supabase
                .from("profiles")
                .select("id, username, handle, avatar_url")
                .or("username.ilike.%\(query)%,handle.ilike.%\(query)%")
                .limit(20)
                .execute()
                .value
            return results
        } catch {
            print("❌ Search users error: \(error)")
            return []
        }
    }

    // MARK: - Fetch mountains for preview

    func fetchPreviewMountains(for collection: TourCollection, limit: Int = 4) async -> [Mountain] {
        let ids = Array(collection.mountain_ids.prefix(limit))
        guard !ids.isEmpty else { return [] }
        do {
            let results: [Mountain] = try await supabase
                .from("mountains")
                .select("*, routes:mountain_routes(*)")
                .in("id", values: ids.map { $0.uuidString })
                .execute()
                .value
            return ids.compactMap { id in results.first { $0.id == id } }
        } catch {
            print("❌ Fetch preview mountains error: \(error)")
            return []
        }
    }
}

// =========================================
// MARK: - Collection Card View (Redesigned)
// =========================================
struct CollectionCardView: View {
    let collection: TourCollection
    var previewMountains: [Mountain] = []
    var memberCount: Int = 0
    var onTap: (() -> Void)? = nil

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image Preview Grid
                ZStack(alignment: .bottomLeading) {
                    imageGrid
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Gradient overlay
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Peak count badge
                    HStack(spacing: 4) {
                        Image(systemName: "mountain.2.fill")
                            .font(.app(size: 10, weight: .bold))
                        Text("\(collection.mountain_ids.count)")
                            .font(.app(size: 11, weight: .black))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(8)

                    // Shared badge top-right
                    if collection.isShared || memberCount > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 3) {
                                    Image(systemName: "person.2.fill")
                                        .font(.app(size: 9))
                                    if memberCount > 0 {
                                        Text("\(memberCount + 1)")
                                            .font(.app(size: 9, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial.opacity(0.7))
                                .clipShape(Capsule())
                                .padding(8)
                            }
                            Spacer()
                        }
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.app(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !collection.description.isEmpty {
                        Text(collection.description)
                            .font(.app(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Mountain name chips
                    if !previewMountains.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(previewMountains.prefix(2)) { mt in
                                Text(mt.name)
                                    .font(.app(size: 9, weight: .semibold))
                                    .foregroundColor(accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            if collection.mountain_ids.count > 2 {
                                Text("+\(collection.mountain_ids.count - 2)")
                                    .font(.app(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageGrid: some View {
        let images = previewMountains.compactMap { $0.effectiveImageUrl }.prefix(4)

        if images.count >= 4 {
            // 2x2 grid
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    mountainImage(url: String(images[0]))
                    mountainImage(url: String(images[1]))
                }
                HStack(spacing: 2) {
                    mountainImage(url: String(images[2]))
                    mountainImage(url: String(images[3]))
                }
            }
        } else if images.count >= 2 {
            // 2 side by side
            HStack(spacing: 2) {
                mountainImage(url: String(images[0]))
                mountainImage(url: String(images[1]))
            }
        } else if let first = images.first {
            // Single image
            mountainImage(url: String(first))
        } else {
            // Gradient placeholder
            LinearGradient(
                colors: [accent.opacity(0.4), accent.opacity(0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.app(size: 28))
                    .foregroundColor(.white.opacity(0.4))
            )
        }
    }

    private func mountainImage(url: String) -> some View {
        GeometryReader { geo in
            CachedAsyncImage(url: URL(string: url)!) { image in
                image.resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } placeholder: {
                Color.gray.opacity(0.15)
            }
        }
        .clipped()
    }
}

// =========================================
// MARK: - Collections View (Redesigned)
// =========================================
struct CollectionsView: View {
    @StateObject private var collectionsManager = CollectionsManager()
    @State private var showCreateSheet = false
    @State private var selectedCollection: TourCollection?
    @State private var previewCache: [UUID: [Mountain]] = [:]
    @State private var memberCountCache: [UUID: Int] = [:]
    @State private var selectedTab: CollectionTab = .mine

    enum CollectionTab: String, CaseIterable {
        case mine = "Mine"
        case shared = "Shared"
        case community = "Community"
    }

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Collections")
                            .font(.app(size: 28, weight: .bold))
                        Text("\(collectionsManager.myCollections.count) collections \u{00B7} \(totalPeaks) peaks")
                            .font(.app(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.app(size: 28))
                            .foregroundColor(accent)
                    }
                }

                // Tab selector
                HStack(spacing: 4) {
                    ForEach(CollectionTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                        } label: {
                            Text(tab.rawValue)
                                .font(.app(size: 13, weight: .bold))
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(selectedTab == tab ? accent : Color.clear)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(3)
                .background(Color(.systemGray6))
                .clipShape(Capsule())

                // Content
                switch selectedTab {
                case .mine:
                    myCollectionsGrid
                case .shared:
                    sharedCollectionsGrid
                case .community:
                    communityCollectionsGrid
                }
            }
            .padding(20)
        }
        .task {
            await collectionsManager.fetchAll()
            await loadPreviews(for: collectionsManager.myCollections)
            await loadPreviews(for: collectionsManager.sharedCollections)
            await loadMemberCounts()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCollectionSheet(manager: collectionsManager)
        }
        .sheet(item: $selectedCollection) { collection in
            CollectionDetailSheet(collection: collection, manager: collectionsManager)
        }
    }

    private var totalPeaks: Int {
        Set(collectionsManager.myCollections.flatMap { $0.mountain_ids }).count
    }

    // MARK: - My Collections Grid

    @ViewBuilder
    var myCollectionsGrid: some View {
        if collectionsManager.myCollections.isEmpty {
            emptyState(
                icon: "rectangle.stack.fill",
                title: "No collections yet",
                subtitle: "Create a collection to organize your favorite peaks."
            )
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(collectionsManager.myCollections) { collection in
                    CollectionCardView(
                        collection: collection,
                        previewMountains: previewCache[collection.id] ?? [],
                        memberCount: memberCountCache[collection.id] ?? 0
                    ) {
                        selectedCollection = collection
                    }
                }
            }
        }
    }

    // MARK: - Shared Collections Grid

    @ViewBuilder
    var sharedCollectionsGrid: some View {
        if collectionsManager.sharedCollections.isEmpty {
            emptyState(
                icon: "person.2.circle",
                title: "No shared collections",
                subtitle: "When friends share a collection with you, it appears here."
            )
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(collectionsManager.sharedCollections) { collection in
                    CollectionCardView(
                        collection: collection,
                        previewMountains: previewCache[collection.id] ?? [],
                        memberCount: memberCountCache[collection.id] ?? 0
                    ) {
                        selectedCollection = collection
                    }
                }
            }
        }
    }

    // MARK: - Community Collections Grid

    @ViewBuilder
    var communityCollectionsGrid: some View {
        if collectionsManager.publicCollections.isEmpty {
            emptyState(
                icon: "globe",
                title: "No community collections",
                subtitle: "Public collections from other alpinists will appear here."
            )
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(collectionsManager.publicCollections) { collection in
                    CollectionCardView(
                        collection: collection,
                        previewMountains: previewCache[collection.id] ?? []
                    ) {
                        selectedCollection = collection
                    }
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.app(size: 44))
                .foregroundColor(.gray.opacity(0.2))
            Text(title)
                .font(.app(.subheadline))
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.app(.caption))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preview Loading

    private func loadPreviews(for collections: [TourCollection]) async {
        for collection in collections {
            guard previewCache[collection.id] == nil else { continue }
            let mountains = await collectionsManager.fetchPreviewMountains(for: collection, limit: 4)
            previewCache[collection.id] = mountains
        }
    }

    private func loadMemberCounts() async {
        for collection in collectionsManager.myCollections {
            let members = await collectionsManager.fetchMembers(collectionId: collection.id)
            memberCountCache[collection.id] = members.count
        }
    }
}

// =========================================
// MARK: - Create Collection Sheet
// =========================================
struct CreateCollectionSheet: View {
    @ObservedObject var manager: CollectionsManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.accent.opacity(0.5), DesignSystem.Colors.accent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)

                    VStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.app(size: 30))
                            .foregroundColor(.white)
                        Text(name.isEmpty ? "Collection Name" : name)
                            .font(.app(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .font(.app(size: 11, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(2)
                    TextField("e.g. Best Peaks in Tirol", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DESCRIPTION")
                        .font(.app(size: 11, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(2)
                    TextField("Optional description...", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                Spacer()

                Button(action: save) {
                    if isSaving { ProgressView().tint(.white) }
                    else { Text("Create Collection") }
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
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let success = await manager.createCollection(
                name: name, description: description, mountainIds: []
            )
            if success { dismiss() }
            isSaving = false
        }
    }
}

// =========================================
// MARK: - Save To Collection Sheet
// =========================================
struct SaveToCollectionSheet: View {
    let mountain: Mountain
    @StateObject private var manager = CollectionsManager()
    @Environment(\.dismiss) var dismiss
    @State private var showCreateSheet = false

    var body: some View {
        NavigationView {
            Group {
                if manager.isLoading {
                    ProgressView()
                } else if manager.myCollections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.app(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No Collections yet")
                            .font(.app(.headline))
                        Text("Create your first collection to save this peak.")
                            .font(.app(.subheadline))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: { showCreateSheet = true }) {
                            Text("Create Collection")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(DesignSystem.Colors.accent)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(manager.myCollections) { collection in
                            Button {
                                Task {
                                    await manager.addMountainToCollection(collectionId: collection.id, mountainId: mountain.id)
                                    HapticManager.shared.success()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(collection.name)
                                            .font(.app(.headline))
                                            .foregroundColor(.primary)
                                        Text("\(collection.mountain_ids.count) peaks")
                                            .font(.app(.caption))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if collection.mountain_ids.contains(mountain.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .disabled(collection.mountain_ids.contains(mountain.id))
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Save to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Cancel").fontWeight(.medium)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await manager.fetchMyCollections()
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateCollectionSheet(manager: manager)
            }
            .onChange(of: showCreateSheet) { _, isPresented in
                if !isPresented {
                    Task { await manager.fetchMyCollections() }
                }
            }
        }
    }
}

// =========================================
// MARK: - Collection Detail Sheet (Redesigned)
// =========================================
struct CollectionDetailSheet: View {
    let collection: TourCollection
    @ObservedObject var manager: CollectionsManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var mountains: [Mountain] = []
    @State private var members: [CollectionMember] = []
    @State private var memberProfiles: [UUID: ShareableUser] = [:]
    @State private var isLoading = false
    @State private var selectedMountain: Mountain?
    @State private var showShareSheet = false
    @State private var showAddPeaksSheet = false

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.945, green: 0.945, blue: 0.96).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Header with mosaic
                        heroHeader

                        // Map showing each peak with its OWN route — no lines between peaks
                        if !mountains.isEmpty {
                            collectionMapSection
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                        }

                        // Stats row — positioned completely below the hero image
                        statsRow
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 0)

                        VStack(alignment: .leading, spacing: 20) {
                            // Action buttons
                            actionButtons

                            // Members section
                            if !members.isEmpty {
                                membersSection
                            }

                            // Mountains list
                            mountainsSection

                            // Delete
                            Button {
                                Task {
                                    await manager.deleteCollection(id: collection.id)
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Collection")
                                }
                                .font(.app(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(20)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
            .task {
                isLoading = true
                async let mtResult = fetchMountains()
                async let memResult = manager.fetchMembers(collectionId: collection.id)
                _ = await mtResult
                members = await memResult
                await fetchMemberProfiles()
                isLoading = false
            }
            .sheet(item: $selectedMountain) { mountain in
                BasecampMountainDetailSheet(mountain: mountain) {
                    selectedMountain = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            appState.activeMountain = mountain
                            withAnimation { appState.isTrackerActive = true }
                        }
                    }
                }
                .presentationDetents([.fraction(0.85), .large])
                .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareCollectionSheet(collection: collection, manager: manager)
            }
            .sheet(isPresented: $showAddPeaksSheet) {
                AddPeaksToCollectionSheet(collection: collection, manager: manager, existingMountains: $mountains)
            }
            .onChange(of: showAddPeaksSheet) { _, isPresented in
                if !isPresented {
                    // Refresh mountains from DB after adding peaks
                    Task {
                        await fetchMountains()
                    }
                }
            }
        }
    }

    // MARK: - Collection Map (per-peak routes, no lines between peaks)

    @ViewBuilder
    var collectionMapSection: some View {
        let validMountains = mountains.filter { $0.latitude != nil && $0.longitude != nil }
        let region = mapRegion(for: validMountains)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Map")
                    .font(.app(size: 16, weight: .bold))
                Spacer()
                Text("\(validMountains.count) peak\(validMountains.count == 1 ? "" : "s")")
                    .font(.app(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Map(initialPosition: .region(region)) {
                // Each peak's own route polyline — peaks are NOT connected
                ForEach(validMountains) { mountain in
                    if let firstRoute = mountain.routes?.first,
                       !firstRoute.route_polyline.isEmpty {
                        let coords = PolylineUtility.decode(polyline: firstRoute.route_polyline)
                        if coords.count >= 2 {
                            MapPolyline(coordinates: coords)
                                .stroke(accent, lineWidth: 4)
                        }
                    }
                }

                ForEach(Array(validMountains.enumerated()), id: \.element.id) { index, mountain in
                    let coord = CLLocationCoordinate2D(
                        latitude: mountain.latitude!,
                        longitude: mountain.longitude!
                    )
                    Annotation(mountain.name, coordinate: coord) {
                        Button { selectedMountain = mountain } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    Circle()
                                        .fill(accent)
                                        .frame(width: 30, height: 30)
                                    Text("\(index + 1)")
                                        .font(.app(size: 13, weight: .black))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                                Text(mountain.name)
                                    .font(.app(size: 10, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
    }

    // Compute a region that fits all mountain coordinates with reasonable padding.
    private func mapRegion(for items: [Mountain]) -> MKCoordinateRegion {
        let coords = items.compactMap { m -> CLLocationCoordinate2D? in
            guard let lat = m.latitude, let lon = m.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 47.0, longitude: 11.0),
                span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
            )
        }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // 1.6× padding so pins aren't on the edge; minimum span so single peak isn't fully zoomed
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.05),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.05)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Hero Header

    @ViewBuilder
    var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Mountain image mosaic
            let images = mountains.compactMap { $0.effectiveImageUrl }.prefix(3)
            if images.count >= 3 {
                HStack(spacing: 2) {
                    mountainCoverImage(url: String(images[0]))
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        mountainCoverImage(url: String(images[1]))
                        mountainCoverImage(url: String(images[2]))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if let first = images.first {
                mountainCoverImage(url: String(first))
            } else {
                LinearGradient(
                    colors: [accent.opacity(0.5), accent.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "mountain.2.fill")
                        .font(.app(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                )
            }

            // Gradient overlay — full coverage bottom half
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.25),
                    .init(color: .black.opacity(0.65), location: 0.85),
                    .init(color: .black.opacity(0.8), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Close button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.app(size: 28))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.3))
                    }
                    .padding(16)
                    .padding(.top, 4)
                }
                Spacer()
            }

            // Title overlay
            VStack(alignment: .leading, spacing: 6) {
                if collection.isShared {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill").font(.app(size: 10))
                        Text("SHARED").font(.app(size: 10, weight: .black)).tracking(1)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }

                Text(collection.name)
                    .font(.app(size: 26, weight: .bold))
                    .foregroundColor(.white)

                if !collection.description.isEmpty {
                    Text(collection.description)
                        .font(.app(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 260)
        .clipped()
    }

    private func mountainCoverImage(url: String) -> some View {
        GeometryReader { geo in
            CachedAsyncImage(url: URL(string: url)!) { image in
                image.resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    var statsRow: some View {
        let totalElev = mountains.reduce(0) { $0 + $1.elevation }
        let regions = Set(mountains.map { $0.region }).count

        HStack(spacing: 0) {
            collectionStat(icon: "mountain.2.fill", value: "\(mountains.count)", label: "Peaks")
            collectionStat(icon: "arrow.up.right", value: "\(totalElev)m", label: "Total Elev.")
            collectionStat(icon: "map", value: "\(regions)", label: "Regions")
            collectionStat(icon: "person.2.fill", value: "\(members.count + 1)", label: "Members")
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    func collectionStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.app(size: 16)).foregroundColor(accent)
            Text(value).font(.app(size: 15, weight: .bold))
            Text(label).font(.app(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    var actionButtons: some View {
        VStack(spacing: 10) {
            // Primary: Add Peaks
            Button { showAddPeaksSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.magnifyingglass")
                    Text("Add Peaks")
                }
                .font(.app(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 12) {
                Button { showShareSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                        Text("Invite")
                    }
                    .font(.app(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                ShareLink(item: URL(string: "https://acend.app/collection/\(collection.id)")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.app(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Members")
                    .font(.app(size: 16, weight: .bold))
                Spacer()
                Button { showShareSheet = true } label: {
                    Image(systemName: "plus.circle")
                        .font(.app(size: 18))
                        .foregroundColor(accent)
                }
            }

            let sortedUserIds = getRankedMembers()
            
            VStack(spacing: 8) {
                ForEach(sortedUserIds, id: \.self) { userId in
                    let profile = memberProfiles[userId]
                    let isOwner = userId == collection.user_id
                    let role = isOwner ? "creator" : (members.first(where: { $0.user_id == userId })?.role ?? "viewer")
                    let level = profile?.level ?? 1
                    
                    HStack(spacing: 12) {
                        // Avatar Tag
                        ZStack {
                            Circle()
                                .fill(roleColor(role).opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            if let urlStr = profile?.avatar_url, let url = URL(string: urlStr) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.clear
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Text(String((profile?.username ?? "?").prefix(1)).uppercased())
                                    .font(.app(size: 16, weight: .bold))
                                    .foregroundColor(roleColor(role))
                            }
                            
                            // Role Badge (Creator/Admin)
                            if isOwner || role == "admin" {
                                Image(systemName: roleIcon(role))
                                    .font(.app(size: 10))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(roleColor(role))
                                    .clipShape(Circle())
                                    .offset(x: 12, y: 12)
                            }
                        }
                        
                        // Name & Level Details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile?.username ?? "Unknown")
                                .font(.app(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Text("Lv. \(level)")
                                    .font(.app(size: 11, weight: .bold))
                                    .foregroundColor(.yellow)
                                
                                Text("·")
                                    .font(.app(size: 11))
                                    .foregroundColor(.gray)
                                
                                Text(role.capitalized)
                                    .font(.app(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
                }
            }
        }
    }
    
    private func getRankedMembers() -> [UUID] {
        var allIds = members.map { $0.user_id }
        if !allIds.contains(collection.user_id) {
            allIds.append(collection.user_id)
        }
        return allIds.sorted { id1, id2 in
            let l1 = memberProfiles[id1]?.level ?? 0
            let l2 = memberProfiles[id2]?.level ?? 0
            if l1 != l2 { return l1 > l2 }
            if id1 == collection.user_id { return true }
            if id2 == collection.user_id { return false }
            return false
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "creator": return .purple
        case "admin": return .orange
        case "editor": return .green
        default: return .blue
        }
    }

    private func roleIcon(_ role: String) -> String {
        switch role {
        case "creator": return "crown.fill"
        case "admin": return "shield.fill"
        case "editor": return "pencil"
        default: return "eye.fill"
        }
    }

    // MARK: - Mountains Section

    @ViewBuilder
    var mountainsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Peaks (\(mountains.count))")
                .font(.app(size: 16, weight: .bold))
                .padding(.horizontal, 20)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(30)
            } else if mountains.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "mountain.2")
                        .font(.app(size: 36))
                        .foregroundColor(.gray.opacity(0.25))
                    Text("No peaks in this collection yet")
                        .font(.app(.subheadline))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(mountains) { mountain in
                            Button { selectedMountain = mountain } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Mountain Image Header
                                    if let urlStr = mountain.effectiveImageUrl, let url = URL(string: urlStr) {
                                        CachedAsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.gray.opacity(0.15)
                                        }
                                        .frame(width: 140, height: 160)
                                        .clipped()
                                    } else {
                                        ZStack {
                                            Color(accent).opacity(0.1)
                                            Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                                                .font(.app(size: 30))
                                                .foregroundColor(accent)
                                        }
                                        .frame(width: 140, height: 160)
                                    }
                                    
                                    // Info Section
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text(mountain.name)
                                                .font(.app(size: 14, weight: .bold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            if mountain.isPrestigePeak {
                                                Image(systemName: "crown.fill")
                                                    .font(.app(size: 10))
                                                    .foregroundColor(.yellow)
                                            }
                                        }
                                        Text("\(mountain.elevation)m · \(mountain.region)")
                                            .font(.app(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            
                                        Text(mountain.difficulty.rawValue)
                                            .font(.app(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(mountain.difficulty.color)
                                            .clipShape(Capsule())
                                            .padding(.top, 4)

                                        // Per-mountain route stats (this peak's own route)
                                        if let stats = routeStats(for: mountain) {
                                            HStack(spacing: 6) {
                                                Label(String(format: "%.1f km", stats.km),
                                                      systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                                    .font(.app(size: 9, weight: .semibold))
                                                    .labelStyle(.titleAndIcon)
                                                    .foregroundColor(.secondary)
                                                Label("+\(stats.gainM)m",
                                                      systemImage: "arrow.up.right")
                                                    .font(.app(size: 9, weight: .semibold))
                                                    .labelStyle(.titleAndIcon)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                    .padding(12)
                                    .frame(width: 140, alignment: .leading)
                                }
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await manager.removeMountainFromCollection(collectionId: collection.id, mountainId: mountain.id)
                                        mountains.removeAll { $0.id == mountain.id }
                                    }
                                } label: {
                                    Label("Remove from Collection", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 4)
                }
                .padding(.horizontal, -20) // to allow scrolling full bleed but text aligns to 20
            }
        }
    }

    // MARK: - Fetch

    private func fetchMountains() async {
        // Fetch fresh collection from manager (may have new mountain_ids after adds)
        let freshIds: [UUID]
        if let updated = manager.myCollections.first(where: { $0.id == collection.id }) {
            freshIds = updated.mountain_ids
        } else {
            freshIds = collection.mountain_ids
        }
        guard !freshIds.isEmpty else { mountains = []; return }
        
        do {
            let idStrings = freshIds.map { $0.uuidString }
            let results: [Mountain] = try await supabase
                .from("mountains")
                .select("*, routes:mountain_routes(*)")
                .in("id", values: idStrings)
                .execute()
                .value
            let ordered = freshIds.compactMap { id in
                results.first(where: { $0.id == id })
            }
            self.mountains = ordered.isEmpty ? results : ordered
        } catch {
            print("❌ Failed to fetch mountains for collection: \(error)")
        }
    }

    // Per-mountain route stats: distance from polyline, elevation gain from profile
    fileprivate func routeStats(for mountain: Mountain) -> (km: Double, gainM: Int)? {
        guard let route = mountain.routes?.first, !route.route_polyline.isEmpty else { return nil }
        let coords = PolylineUtility.decode(polyline: route.route_polyline)
        guard coords.count >= 2 else { return nil }

        var meters: CLLocationDistance = 0
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            meters += b.distance(from: a)
        }

        var gain = 0
        if let elevs = route.elevation_profile, elevs.count >= 2 {
            for i in 1..<elevs.count {
                let delta = elevs[i] - elevs[i - 1]
                if delta > 0 { gain += delta }
            }
        }
        return (km: meters / 1000.0, gainM: gain)
    }

    private func fetchMemberProfiles() async {
        var ids = members.map { $0.user_id.uuidString }
        if !ids.contains(collection.user_id.uuidString) {
            ids.append(collection.user_id.uuidString)
        }
        guard !ids.isEmpty else { return }
        do {
            let profiles: [ShareableUser] = try await supabase
                .from("profiles")
                .select("id, username, handle, avatar_url, level, xp")
                .in("id", values: ids)
                .execute()
                .value
            var dict: [UUID: ShareableUser] = [:]
            for p in profiles { dict[p.id] = p }
            await MainActor.run {
                self.memberProfiles = dict
            }
        } catch {
            print("❌ Failed to fetch member profiles: \(error)")
        }
    }
}

// =========================================
// MARK: - Add Peaks to Collection Sheet
// =========================================
struct AddPeaksToCollectionSheet: View {
    let collection: TourCollection
    @ObservedObject var manager: CollectionsManager
    @Binding var existingMountains: [Mountain]
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var searchResults: [Mountain] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var addedIds: Set<UUID> = []
    @State private var isSaving = false

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search peaks by name or region...", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "mountain.2.fill")
                            .font(.app(size: 44))
                            .foregroundColor(.gray.opacity(0.2))
                        Text("Search for peaks to add")
                            .font(.app(.subheadline))
                            .foregroundColor(.secondary)
                        Text("Type a mountain name or region")
                            .font(.app(.caption))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else if isSearching {
                    Spacer()
                    ProgressView().padding(24)
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    Text("No peaks found")
                        .font(.app(.subheadline))
                        .foregroundColor(.secondary)
                        .padding(24)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(searchResults) { mountain in
    
                                let isAlreadyInCollection = collection.mountain_ids.contains(mountain.id)
                                let isSelected = addedIds.contains(mountain.id)
                                Button {
                                    guard !isAlreadyInCollection else { return }
                                    if isSelected {
                                        addedIds.remove(mountain.id)
                                    } else {
                                        addedIds.insert(mountain.id)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        if let urlStr = mountain.effectiveImageUrl, let url = URL(string: urlStr) {
                                            CachedAsyncImage(url: url) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Color.gray.opacity(0.15)
                                            }
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(accent.opacity(0.1))
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Image(systemName: "mountain.2.fill")
                                                        .font(.app(size: 16))
                                                        .foregroundColor(accent)
                                                )
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 5) {
                                                Text(mountain.name)
                                                    .font(.app(size: 15, weight: .bold))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                if mountain.isPrestigePeak {
                                                    Image(systemName: "crown.fill")
                                                        .font(.app(size: 9))
                                                        .foregroundColor(.yellow)
                                                }
                                            }
                                            Text("\(mountain.elevation)m · \(mountain.region)")
                                                .font(.app(size: 12))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        if isAlreadyInCollection {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.app(size: 22))
                                                .foregroundColor(.gray.opacity(0.5))
                                        } else if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.app(size: 22))
                                                .foregroundColor(.green)
                                        } else {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.app(size: 22))
                                                .foregroundColor(accent)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(isAlreadyInCollection)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }
            }
            .background(Color(red: 0.945, green: 0.945, blue: 0.96))
            .navigationTitle("Add Peaks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task {
                            isSaving = true
                            for id in addedIds {
                                await manager.addMountainToCollection(collectionId: collection.id, mountainId: id)
                                if let m = searchResults.first(where: { $0.id == id }) {
                                    existingMountains.append(m)
                                }
                            }
                            isSaving = false
                            dismiss()
                        }
                    }
                    .font(.app(.body).weight(.bold))
                    .disabled(addedIds.isEmpty || isSaving)
                    .foregroundColor(addedIds.isEmpty ? .gray : accent)
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { searchResults = []; return }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    await performSearch(query: trimmed)
                    isSearching = false
                }
            }
        }
    }

    private func performSearch(query: String) async {
        let safe = query
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safe.isEmpty else { searchResults = []; return }
        do {
            let results: [Mountain] = try await supabase
                .from("mountains")
                .select("*, routes:mountain_routes(*)")
                .or("name.ilike.%\(safe)%,region.ilike.%\(safe)%,country.ilike.%\(safe)%")
                .limit(30)
                .execute()
                .value
            
            // Optional: minimal sorting to prioritize exact starts
            let safeLower = safe.lowercased()
            let sortedResults = results.sorted { m1, m2 in
                let n1 = m1.name.lowercased()
                let n2 = m2.name.lowercased()
                let s1 = n1.starts(with: safeLower)
                let s2 = n2.starts(with: safeLower)
                if s1 && !s2 { return true }
                if s2 && !s1 { return false }
                return m1.elevation > m2.elevation
            }
            
            self.searchResults = sortedResults
        } catch {
            print("❌ Peak search error: \(error)")
        }
    }
}

// =========================================
// MARK: - Share Collection Sheet
// =========================================
struct ShareCollectionSheet: View {
    let collection: TourCollection
    @ObservedObject var manager: CollectionsManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var searchText = ""
    @State private var searchResults: [ShareableUser] = []
    @State private var isSearching = false
    @State private var currentMembers: [CollectionMember] = []
    @State private var memberProfiles: [UUID: ShareableUser] = [:]
    @State private var selectedRole = "viewer"
    @State private var searchTask: Task<Void, Never>?

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search by username or handle...", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Role selector
                HStack(spacing: 8) {
                    ForEach(["viewer", "editor", "admin"], id: \.self) { role in
                        Button {
                            selectedRole = role
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: roleIcon(role))
                                    .font(.app(size: 11))
                                Text(role.capitalized)
                            }
                            .font(.app(size: 12, weight: .bold))
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
                        ProgressView().padding(24)
                    } else if searchResults.isEmpty {
                        Text("No users found")
                            .font(.app(.subheadline))
                            .foregroundColor(.secondary)
                            .padding(24)
                    } else {
                        List {
                            ForEach(searchResults) { user in
                                userRow(user: user)
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    // Friends & Current Members
                    ScrollView {
                        VStack(spacing: 24) {
                            if !appState.friendsLeaderboard.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Invite Friends")
                                        .font(.app(size: 14, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                    
                                    LazyVStack(spacing: 0) {
                                        ForEach(appState.friendsLeaderboard) { friend in
                                            let friendUser = ShareableUser(id: friend.id, username: friend.username, handle: friend.handle, avatar_url: friend.avatar_url)
                                            userRow(user: friendUser)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                                .padding(.top, 16)
                            }
                            
                            if !currentMembers.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Members (\(currentMembers.count))")
                                        .font(.app(size: 14, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                    
                                    LazyVStack(spacing: 0) {
                                        ForEach(currentMembers) { member in
                                            memberRow(member: member)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                                .padding(.top, appState.friendsLeaderboard.isEmpty ? 16 : 0)
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.app(.body).weight(.bold))
                }
            }
            .task {
                currentMembers = await manager.fetchMembers(collectionId: collection.id)
                await fetchMemberProfilesForShare()
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    searchResults = []; return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    searchResults = await manager.searchUsers(query: newValue)
                    isSearching = false
                }
            }
        }
    }


    @ViewBuilder
    private func userRow(user: ShareableUser) -> some View {
        let alreadyMember = currentMembers.contains { $0.user_id == user.id }
        Button {
            guard !alreadyMember else { return }
            Task {
                let success = await manager.addMember(
                    collectionId: collection.id,
                    userId: user.id,
                    role: selectedRole
                )
                if success {
                    HapticManager.shared.success()
                    currentMembers = await manager.fetchMembers(collectionId: collection.id)
                    searchText = ""
                    searchResults = []
                }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.app(size: 17, weight: .bold))
                            .foregroundColor(accent)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.username)
                        .font(.app(.headline))
                        .foregroundColor(.primary)
                    Text("@\(user.handle)")
                        .font(.app(.caption))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if alreadyMember {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(accent)
                }
            }
        }
        .disabled(alreadyMember)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func memberRow(member: CollectionMember) -> some View {
        let profile = memberProfiles[member.user_id]
        HStack(spacing: 12) {
            Circle()
                .fill(roleColor(member.role).opacity(0.15))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(String((profile?.username ?? "?").prefix(1)).uppercased())
                        .font(.app(size: 15, weight: .bold))
                        .foregroundColor(roleColor(member.role))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(profile?.username ?? "Loading...")
                    .font(.app(.subheadline))
                if let handle = profile?.handle {
                    Text("@\(handle) · \(member.role.capitalized)")
                        .font(.app(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text(member.role.capitalized)
                        .font(.app(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                Task {
                    await manager.removeMember(collectionId: collection.id, userId: member.user_id)
                    currentMembers = await manager.fetchMembers(collectionId: collection.id)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "admin": return .orange
        case "editor": return .green
        default: return .blue
        }
    }

    private func roleIcon(_ role: String) -> String {
        switch role {
        case "admin": return "shield.fill"
        case "editor": return "pencil"
        default: return "eye.fill"
        }
    }

    private func fetchMemberProfilesForShare() async {
        let ids = currentMembers.map { $0.user_id.uuidString }
        guard !ids.isEmpty else { return }
        do {
            let profiles: [ShareableUser] = try await supabase
                .from("profiles")
                .select("id, username, handle, avatar_url")
                .in("id", values: ids)
                .execute()
                .value
            var dict: [UUID: ShareableUser] = [:]
            for p in profiles { dict[p.id] = p }
            self.memberProfiles = dict
        } catch {
            print("❌ Failed to fetch member profiles: \(error)")
        }
    }
}
