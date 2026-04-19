import SwiftUI

// Globale Schriftart-Einstellung mit den zwei neuen Custom Fonts:
// - CabinetGrotesk-Bold für Überschriften und große Namen
// - Satoshi-Regular für Lauftext, Chat, kleine Labels

extension Font {
    static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // High-contrast technical look: CabinetGrotesk for headings, Satoshi for UI
        let isHeading = size >= 18 || weight == .bold || weight == .heavy || weight == .black
        
        if isHeading {
            return Font.custom("CabinetGrotesk-Bold", size: size)
        } else {
            return Font.custom("Satoshi-Regular", size: size)
        }
    }

    /// Technical instrument-readout font (Monospaced).
    /// Used for telemetry, altimeter, and numeric stats.
    static func appMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    /// Rounded variants for secondary status labels / pills.
    static func appTech(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }

    static func app(_ style: Font.TextStyle) -> Font {
        switch style {
        case .largeTitle: return .app(size: 34, weight: .black)
        case .title:      return .app(size: 28, weight: .bold)
        case .title2:     return .app(size: 22, weight: .bold)
        case .title3:     return .app(size: 20, weight: .bold)
        case .headline:   return .app(size: 17, weight: .bold)
        case .body:       return .app(size: 16, weight: .regular)
        case .callout:    return .app(size: 15, weight: .regular)
        case .subheadline: return .app(size: 14, weight: .regular)
        case .footnote:   return .app(size: 12, weight: .medium)
        case .caption:    return .app(size: 11, weight: .medium)
        case .caption2:   return .app(size: 10, weight: .bold)
        @unknown default: return .app(size: 16, weight: .regular)
        }
    }
}
