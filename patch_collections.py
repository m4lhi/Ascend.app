import sys

with open("Ascent/CollectionsManager.swift", "r") as f:
    content = f.read()

old = """@MainActor
class CollectionsManager: ObservableObject {
    @Published var myCollections: [TourCollection] = []
    @Published var sharedCollections: [TourCollection] = []
    @Published var publicCollections: [TourCollection] = []
    @Published var isLoading = false

    // MARK: - Collections CRUD"""

new = """@MainActor
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

    // MARK: - Collections CRUD"""

content = content.replace(old, new)

with open("Ascent/CollectionsManager.swift", "w") as f:
    f.write(content)
