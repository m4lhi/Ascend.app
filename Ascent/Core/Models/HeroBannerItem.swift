import Foundation

// =========================================
// === DATEI: HeroBannerItem.swift ===
// === Discovery hero-banner card ===
// =========================================
//
// UI model for the home-page hero banner (PRESTIGE PEAK /
// RECOMMENDED / community highlights). Built by
// DiscoveryViewModel.fetchRecommendedPeaks. Extracted from AppState
// so DiscoveryViewModel can hold the array without pulling AppState.

struct HeroBannerItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: String?
    let badge: String?       // e.g. "PRESTIGE PEAK", "TRENDING", "COMMUNITY"
    let mountain: Mountain?  // nil for community highlights
}
