import SwiftUI

// Globale Schriftart-Einstellung mit den zwei neuen Custom Fonts:
// - CabinetGrotesk-Bold für Überschriften und große Namen
// - Satoshi-Regular für Lauftext, Chat, kleine Labels

extension Font {
    static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Alles ab Größe 20 oder explizit fette Typo betrachten wir als Überschrift
        let isHeading = size >= 20 || weight == .bold || weight == .heavy || weight == .black
        
        if isHeading {
            return Font.custom("CabinetGrotesk-Bold", size: size)
        } else {
            return Font.custom("Satoshi-Regular", size: size)
        }
    }

    static func app(_ style: Font.TextStyle) -> Font {
        switch style {
        case .largeTitle:
            return Font.custom("CabinetGrotesk-Bold", size: 34)
        case .title:
            return Font.custom("CabinetGrotesk-Bold", size: 28)
        case .title2:
            return Font.custom("CabinetGrotesk-Bold", size: 22)
        case .title3:
            return Font.custom("CabinetGrotesk-Bold", size: 20)
        case .headline:
            return Font.custom("CabinetGrotesk-Bold", size: 17)
            
        case .body:
            return Font.custom("Satoshi-Regular", size: 17)
        case .callout:
            return Font.custom("Satoshi-Regular", size: 16)
        case .subheadline:
            return Font.custom("Satoshi-Regular", size: 15)
        case .footnote:
            return Font.custom("Satoshi-Regular", size: 13)
        case .caption:
            return Font.custom("Satoshi-Regular", size: 12)
        case .caption2:
            return Font.custom("Satoshi-Regular", size: 11)
        @unknown default:
            return Font.custom("Satoshi-Regular", size: 16)
        }
    }
}
