import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: DiscoveryViewModel.swift ===
// === Mountain discovery surface ===
// =========================================
//
// Owns the discovery-domain arrays (recommendedPeaks, suggestedRoutes,
// heroBannerItems) that AppState used to host. Single fetch entry
// point pulls from Supabase `mountains` and shapes three derived
// collections.
//
// PRAGMATIC NOTE (R3 step 5): no dedicated DiscoveryService. The fetch
// is a single Supabase call; wrapping it in a service-of-one would be
// over-engineering. Pivot R-P3 will strip suggestedRoutes /
// heroBannerItems and reshape recommendedPeaks into featuredMountains
// anyway. heroBannerItems is currently never consumed by any view —
// migrated 1:1 from AppState behavior; R-P3 makes the strip call.

@MainActor
final class DiscoveryViewModel: ObservableObject {
    @Published private(set) var recommendedPeaks: [Mountain] = []
    @Published private(set) var heroBannerItems: [HeroBannerItem] = []
    @Published private(set) var suggestedRoutes: [Mountain] = []

    /// Idempotent first-load. Bails out if recommendedPeaks already
    /// populated (matches AppState.fetchRecommendedPeaks semantics).
    func fetchRecommendedPeaks() {
        guard recommendedPeaks.isEmpty else { return }

        Task {
            do {
                let rawPeaks: [Mountain] = try await supabase
                    .from("mountains")
                    .select("*, routes:mountain_routes(*)")
                    .not("image_url", operator: .is, value: "null")
                    .neq("image_url", value: "")
                    .limit(200)
                    .execute()
                    .value

                let allPeaks = rawPeaks.filter { ($0.effectiveImageUrl ?? "").count > 5 }

                let displayPeaks = Array(allPeaks.shuffled().prefix(10))
                let routeSuggestions = Array(allPeaks.shuffled().prefix(8))

                var bannerItems: [HeroBannerItem] = []
                for peak in allPeaks.filter({ $0.isPrestigePeak }).shuffled().prefix(3) {
                    bannerItems.append(HeroBannerItem(
                        title: peak.name,
                        subtitle: "\(peak.elevation)m · \(peak.region)",
                        imageURL: (peak.effectiveImageUrl?.isEmpty == false) ? peak.effectiveImageUrl : nil,
                        badge: "PRESTIGE PEAK",
                        mountain: peak
                    ))
                }
                for peak in allPeaks.filter({ !$0.isPrestigePeak }).shuffled().prefix(3) {
                    bannerItems.append(HeroBannerItem(
                        title: peak.name,
                        subtitle: "\(peak.elevation)m · \(peak.region)",
                        imageURL: (peak.effectiveImageUrl?.isEmpty == false) ? peak.effectiveImageUrl : nil,
                        badge: "RECOMMENDED",
                        mountain: peak
                    ))
                }
                let finalBanner = Array(bannerItems.shuffled().prefix(5))

                self.recommendedPeaks = displayPeaks
                self.suggestedRoutes = routeSuggestions
                self.heroBannerItems = finalBanner
                print("✅ Erfolgreich \(allPeaks.count) Berge von Supabase geladen!")
            } catch {
                print("❌ Fehler beim Laden der Peaks von Supabase: \(error)")
                print("💡 Tipp: Wenn dies passiert, weichen die Spalten in Supabase wahrscheinlich vom 'Mountain' Modell ab (z.B. imageUrl vs image_url oder falscher Datentyp).")
            }
        }
    }
}
