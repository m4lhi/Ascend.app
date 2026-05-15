import Foundation
import SwiftUI
import Supabase

// Simple wrap/flow layout for tag clouds (iOS 16+)
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// =========================================
// === DATEI: HobbiesRepository.swift ===
// === Gemeinsames Hobbies-Verzeichnis (Supabase-backed) ===
// =========================================

struct HobbyEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let normalized_name: String
    let usage_count: Int
}

@MainActor
final class HobbiesRepository {
    static let shared = HobbiesRepository()
    private init() {}

    /// Normalizes a user-typed hobby: trims whitespace, collapses spaces,
    /// title-cases. Used for client-side display & deduplication before DB.
    static func clean(_ raw: String) -> String {
        let collapsed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !collapsed.isEmpty else { return "" }
        return collapsed
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    /// Validates: 2–40 chars, letters/spaces/hyphens only.
    static func isValid(_ name: String) -> Bool {
        let cleaned = clean(name)
        guard cleaned.count >= 2, cleaned.count <= 40 else { return false }
        let allowed = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-"))
        return cleaned.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Search the shared hobbies dictionary (case-insensitive, prefix + contains).
    func search(query: String, limit: Int = 10) async throws -> [HobbyEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let results: [HobbyEntry] = try await supabase
            .from("hobbies")
            .select()
            .ilike("normalized_name", pattern: "%\(q)%")
            .order("usage_count", ascending: false)
            .limit(limit)
            .execute()
            .value
        return results
    }

    /// Register or bump a hobby via RPC. Returns the canonical stored name.
    @discardableResult
    func register(name: String) async throws -> String {
        let cleaned = Self.clean(name)
        guard Self.isValid(cleaned) else { return cleaned }
        let params: [String: String] = ["p_name": cleaned]
        let row: HobbyEntry = try await supabase
            .rpc("register_hobby", params: params)
            .single()
            .execute()
            .value
        return row.name
    }
}
