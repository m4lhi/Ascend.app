import Foundation
import Supabase

// =========================================
// === DATEI: ProfileService.swift ===
// === Network layer for the user profile ===
// =========================================
//
// Wraps Supabase calls for the `profiles` table and avatar storage.
// Stateless — no @Published, no in-memory cache. Callers
// (ProfileViewModel) hold the resulting CloudProfile in their own
// observable surface. The Service intentionally does not reference
// AppState or any ViewModel.

final class ProfileService {
    static let shared = ProfileService()
    private init() {}

    /// Fetch the authenticated user's profile row.
    func fetchProfile() async throws -> CloudProfile {
        let session = try await supabase.auth.session
        let userId = session.user.id
        return try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    /// Fetch profile rows whose handle matches the given pattern (ILIKE).
    /// Returns an array — handle isn't database-unique, caller picks first.
    func fetchProfilesByHandle(_ pattern: String) async throws -> [CloudProfile] {
        try await supabase
            .from("profiles")
            .select()
            .ilike("handle", pattern: pattern)
            .execute()
            .value
    }

    /// Upsert (create-or-update) the given profile row.
    func upsertProfile(_ profile: CloudProfile) async throws {
        try await supabase
            .from("profiles")
            .upsert(profile)
            .execute()
    }

    /// Upload a JPEG avatar to Supabase Storage, return the cache-busted
    /// public URL. Caller persists the URL onto the profile row separately
    /// (via upsertProfile).
    func uploadAvatar(data: Data) async throws -> String {
        let userId = try await supabase.auth.session.user.id
        let path = "\(userId).jpg"
        try await supabase.storage
            .from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"
    }
}
