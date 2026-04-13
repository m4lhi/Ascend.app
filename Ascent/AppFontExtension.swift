import SwiftUI

// Globale Schriftart-Einstellung:
// Um alle Texte in der App anzupassen, einfach .rounded, .serif, .monospaced 
// oder .custom("DeinFontName", size: size) eintragen!

extension Font {
    static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Ändere hier den 'design' parameter (z.B. .serif, .monospaced etc.) um es live in der App zu sehen!
        return Font.system(size: size, weight: weight, design: .serif)
    }

    static func app(_ style: Font.TextStyle) -> Font {
        // Gleiches für TextStyles
        return Font.system(style, design: .serif)
    }
}
