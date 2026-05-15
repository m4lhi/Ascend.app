import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: ProfileViewModel.swift ===
// === User profile @Published surface ===
// =========================================
//
// Owns the user's profile state and exposes the read/write methods that
// AppState used to host directly. Delegates all Supabase work to
// ProfileService — never imports AppState.
//
// Not wired into the app environment yet — that happens in the next
// commit. Adding this class alone keeps the build additive.
//
// MARK: - Transitional fields
//
// `lastFetchedProfile` is exposed so AppState can read xp/level from the
// fetched row and apply them to its still-owned currentXP / currentLevel
// mirror. Both fields move to ProgressViewModel in R5; this seam goes
// away then.

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Identity

    @Published var userName: String = "New Alpinist"
    @Published var userHandle: String = "climber"
    @Published var avatarURL: String? = nil
    @Published var userRegion: String = ""
    @Published var instaHandle: String = "alpinist_life"

    // MARK: - Tags & interests

    @Published var selectedSports: [String] = []                                  // CloudProfile.disciplines
    @Published var mountaineeringSpecialties: [String] = ["Ice Climbing", "Scrambling"]
    @Published var otherHobbies: [String] = ["Boxing", "Soccer"]

    // MARK: - Workflow / equipment

    @Published var profileImage: Data? = nil                                      // edit-sheet upload buffer
    @Published var equipment: Equipment = Equipment()

    // MARK: - Transitional surface (R5 removes this)

    @Published private(set) var lastFetchedProfile: CloudProfile? = nil

    private let service: ProfileService = .shared

    // MARK: - Read

    /// Fetch the user's profile row. On a 404-style error (no row yet),
    /// generate a random handle and create the row.
    func fetchProfile() async {
        do {
            let profile = try await service.fetchProfile()
            apply(profile)
            self.lastFetchedProfile = profile
        } catch {
            if userHandle == "climber" {
                userHandle = "climber_\(Int.random(in: 1000...9999))"
            }
            await createProfileInCloud(xp: 0, level: 1)
        }
    }

    // MARK: - Write

    /// Edit-sheet save path. Returns true on success. Local state is
    /// updated optimistically after the upsert succeeds.
    func updateProfile(
        newName: String,
        newHandle: String,
        newRegion: String,
        newSports: [String],
        newInsta: String,
        newHobbies: [String],
        newSpecialties: [String],
        currentXP: Int,
        currentLevel: Int
    ) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let updated = CloudProfile(
                id: session.user.id,
                username: newName,
                handle: newHandle,
                xp: currentXP,
                level: currentLevel,
                avatar_url: self.avatarURL,
                region: newRegion,
                insta_handle: newInsta,
                disciplines: newSports,
                specialties: newSpecialties,
                hobbies: newHobbies
            )
            try await service.upsertProfile(updated)

            for hobby in newHobbies {
                Task.detached { try? await HobbiesRepository.shared.register(name: hobby) }
            }

            self.userName = newName
            self.userHandle = newHandle
            self.userRegion = newRegion
            self.selectedSports = newSports
            self.instaHandle = newInsta
            self.otherHobbies = newHobbies
            self.mountaineeringSpecialties = newSpecialties
            self.lastFetchedProfile = updated
            return true
        } catch {
            print("❌ ProfileViewModel.updateProfile error: \(error)")
            return false
        }
    }

    /// Upload a new avatar image, store the cache-busted URL locally
    /// and persist it on the profile row.
    func uploadAvatar(data: Data, currentXP: Int, currentLevel: Int) async {
        do {
            let newURL = try await service.uploadAvatar(data: data)
            self.avatarURL = newURL

            let session = try await supabase.auth.session
            let updated = CloudProfile(
                id: session.user.id,
                username: self.userName,
                handle: self.userHandle,
                xp: currentXP,
                level: currentLevel,
                avatar_url: newURL,
                region: self.userRegion,
                insta_handle: self.instaHandle,
                disciplines: self.selectedSports,
                specialties: self.mountaineeringSpecialties,
                hobbies: self.otherHobbies
            )
            try await service.upsertProfile(updated)
            self.lastFetchedProfile = updated
        } catch {
            print("❌ ProfileViewModel.uploadAvatar error: \(error)")
        }
    }

    // MARK: - Private

    private func apply(_ p: CloudProfile) {
        self.userName = p.username
        self.userHandle = p.handle
        self.avatarURL = p.avatar_url
        self.userRegion = p.region ?? ""
        self.instaHandle = p.insta_handle ?? ""
        self.selectedSports = p.disciplines ?? []
        self.mountaineeringSpecialties = p.specialties ?? []
        self.otherHobbies = p.hobbies ?? []
    }

    private func createProfileInCloud(xp: Int, level: Int) async {
        do {
            let session = try await supabase.auth.session
            let fresh = CloudProfile(
                id: session.user.id,
                username: userName,
                handle: userHandle,
                xp: xp,
                level: level,
                avatar_url: avatarURL,
                region: userRegion,
                insta_handle: instaHandle,
                disciplines: selectedSports,
                specialties: mountaineeringSpecialties,
                hobbies: otherHobbies
            )
            try await service.upsertProfile(fresh)
            self.lastFetchedProfile = fresh
        } catch {
            print("❌ ProfileViewModel.createProfileInCloud error: \(error)")
        }
    }
}
