import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: CollectionsManager.swift ===
// === Kuratierte Tourensammlungen ===
// =========================================

struct TourCollection: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    var name: String
    var description: String
    var cover_image_url: String?
    var mountain_ids: [UUID]
    var is_public: Bool
    var created_at: Date
    var updated_at: Date

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, description
        case cover_image_url, mountain_ids
        case is_public, created_at, updated_at
    }
}

struct CollectionWithMountains: Identifiable {
    let id: UUID
    let collection: TourCollection
    let mountains: [Mountain]
    var totalElevation: Int { mountains.reduce(0) { $0 + $1.elevation } }
    var peakCount: Int { mountains.count }
}

@MainActor
class CollectionsManager: ObservableObject {
    @Published var myCollections: [TourCollection] = []
    @Published var publicCollections: [TourCollection] = []
    @Published var isLoading = false

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

    func fetchPublicCollections() async {
        do {
            let results: [TourCollection] = try await supabase
                .from("collections")
                .select()
                .eq("is_public", value: true)
                .order("created_at", ascending: false)
                .limit(30)
                .execute()
                .value
            self.publicCollections = results
        } catch {
            print("❌ Fetch public collections error: \(error)")
        }
    }

    func createCollection(name: String, description: String, mountainIds: [UUID], isPublic: Bool) async -> Bool {
        do {
            let userId = try await supabase.auth.session.user.id
            let collection = TourCollection(
                id: UUID(),
                user_id: userId,
                name: name,
                description: description,
                cover_image_url: nil,
                mountain_ids: mountainIds,
                is_public: isPublic,
                created_at: Date(),
                updated_at: Date()
            )
            try await supabase.from("collections").insert(collection).execute()
            await fetchMyCollections()
            return true
        } catch {
            print("❌ Create collection error: \(error)")
            return false
        }
    }

    func addMountainToCollection(collectionId: UUID, mountainId: UUID) async {
        guard var collection = myCollections.first(where: { $0.id == collectionId }) else { return }
        guard !collection.mountain_ids.contains(mountainId) else { return }

        collection.mountain_ids.append(mountainId)
        collection.updated_at = Date()

        do {
            try await supabase.from("collections").upsert(collection).execute()
            await fetchMyCollections()
        } catch {
            print("❌ Add to collection error: \(error)")
        }
    }

    func removeMountainFromCollection(collectionId: UUID, mountainId: UUID) async {
        guard var collection = myCollections.first(where: { $0.id == collectionId }) else { return }
        collection.mountain_ids.removeAll { $0 == mountainId }
        collection.updated_at = Date()

        do {
            try await supabase.from("collections").upsert(collection).execute()
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
}

// MARK: - Collection Card View
struct CollectionCardView: View {
    let collection: TourCollection
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 10) {
                // Cover
                ZStack {
                    if let url = collection.cover_image_url, let imageURL = URL(string: url) {
                        CachedAsyncImage(url: imageURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            gradientPlaceholder
                        }
                    } else {
                        gradientPlaceholder
                    }
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(collection.name)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        if collection.is_public {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("\(collection.mountain_ids.count) peaks")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)

                    if !collection.description.isEmpty {
                        Text(collection.description)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(AscentButtonStyle())
    }

    private var gradientPlaceholder: some View {
        LinearGradient(
            colors: [DesignSystem.Colors.accent.opacity(0.6), DesignSystem.Colors.accent.opacity(0.3)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.5))
        )
    }
}

// MARK: - Collections List View
struct CollectionsView: View {
    @StateObject private var collectionsManager = CollectionsManager()
    @State private var showCreateSheet = false
    @State private var selectedCollection: TourCollection?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // My Collections
                HStack {
                    Text("My Collections")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                }

                if collectionsManager.myCollections.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(collectionsManager.myCollections) { collection in
                            CollectionCardView(collection: collection) {
                                selectedCollection = collection
                            }
                        }
                    }
                }

                // Public Collections
                if !collectionsManager.publicCollections.isEmpty {
                    Text("Community Collections")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(collectionsManager.publicCollections) { collection in
                            CollectionCardView(collection: collection) {
                                selectedCollection = collection
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .task {
            await collectionsManager.fetchMyCollections()
            await collectionsManager.fetchPublicCollections()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCollectionSheet(manager: collectionsManager)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.3))
            Text("No collections yet")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
            Text("Create a collection to organize your favorite peaks and routes.")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Create Collection Sheet
struct CreateCollectionSheet: View {
    @ObservedObject var manager: CollectionsManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(2)
                    TextField("e.g. Best Peaks in Tirol", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DESCRIPTION")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(2)
                    TextField("Optional description...", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                Toggle(isOn: $isPublic) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Public Collection")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            Text("Visible to all users")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(DesignSystem.Colors.accent)

                Spacer()

                Button(action: save) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Create Collection")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.isEmpty || isSaving)
            }
            .padding(20)
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let success = await manager.createCollection(
                name: name, description: description, mountainIds: [], isPublic: isPublic
            )
            if success { dismiss() }
            isSaving = false
        }
    }
}
