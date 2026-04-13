import re
import os

filepath = "Ascent/DesignSystem.swift"
with open(filepath, 'r') as f:
    content = f.read()

# Verify if we need to add the functions
if "func appFont(" not in content:
    replacement = """
        static func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            let fontChoice = currentFont
            if let custom = fontChoice.customName {
                return Font.custom(custom, size: size).weight(weight)
            } else {
                return Font.system(size: size, weight: weight, design: fontChoice.design ?? .default)
            }
        }

        static func appFont(style: Font.TextStyle) -> Font {
            let fontChoice = currentFont
            if let custom = fontChoice.customName {
                // Approximate sizes for TextStyles
                var size: CGFloat = 16
                switch style {
                case .largeTitle: size = 34
                case .title: size = 28
                case .title2: size = 22
                case .title3: size = 20
                case .headline: size = 17
                case .body: size = 17
                case .callout: size = 16
                case .subheadline: size = 15
                case .footnote: size = 13
                case .caption: size = 12
                case .caption2: size = 11
                @unknown default: size = 17
                }
                return Font.custom(custom, size: size)
            } else {
                return Font.system(style, design: fontChoice.design ?? .default)
            }
        }
    """
    # Find `static var heroTitle` and insert before it
    content = content.replace("static var heroTitle", replacement + "\n        static var heroTitle")

    # The python script from previous step changed some styles to `.font(DesignSystem.Typography.appFont(style: .title3))`
    # wait, the regex output `.font(DesignSystem.Typography.appFont(style: .\1))` but the previous script generated `.font(DesignSystem.Typography.appFont(style: .title3))`
    # .fontWeight(...) might be used after it. We should be good.

    with open(filepath, 'w') as f:
        f.write(content)
