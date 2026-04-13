import sys

with open("Ascent/CollectionsManager.swift", "r") as f:
    content = f.read()

old = """    private func fetchMountains() async {
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
    }"""

new = """    private func fetchMountains() async {
        // Fetch fresh collection from manager (may have new mountain_ids after adds)
        let freshIds: [UUID]
        if let updated = manager.myCollections.first(where: { $0.id == collection.id }) {
            freshIds = updated.mountain_ids
        } else {
            freshIds = collection.mountain_ids
        }
        guard !freshIds.isEmpty else { mountains = []; return }
        
        // Use generic cache if possible
        if let cached = MountainDatabase.shared.getMountains(ids: freshIds) {
            self.mountains = cached
            return
        }
        
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
            MountainDatabase.shared.store(mountains: results)
        } catch {
            print("❌ Failed to fetch mountains for collection: \(error)")
        }
    }"""

content = content.replace(old, new)

with open("Ascent/CollectionsManager.swift", "w") as f:
    f.write(content)
