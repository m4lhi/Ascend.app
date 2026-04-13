import sys

with open("Ascent/MountainDatabase.swift", "r") as f:
    content = f.read()

old = """struct MountainDatabase {
    static let mockUserPrestige: [UserMountainPrestige] = []
    
    // Die Berge werden jetzt asynchron über den MountainManager aus Supabase geladen.
    static var all: [Mountain] = []
    
    static var prestigePeaks: [Mountain] {
        all.filter { $0.isPrestigePeak }
    }
}"""

new = """class MountainDatabase {
    static let shared = MountainDatabase()
    static let mockUserPrestige: [UserMountainPrestige] = []
    
    static var all: [Mountain] = []
    static var prestigePeaks: [Mountain] {
        all.filter { $0.isPrestigePeak }
    }
    
    private var mountainCache: [UUID: Mountain] = [:]
    
    func getMountains(ids: [UUID]) -> [Mountain]? {
        var result: [Mountain] = []
        for id in ids {
            if let m = mountainCache[id] {
                result.append(m)
            } else {
                return nil // not fully cached
            }
        }
        return result
    }
    
    func store(mountains: [Mountain]) {
        for m in mountains {
            mountainCache[m.id] = m
        }
    }
}"""

content = content.replace(old, new)

with open("Ascent/MountainDatabase.swift", "w") as f:
    f.write(content)
