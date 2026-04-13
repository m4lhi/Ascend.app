import SwiftUI

struct FontSettingsView: View {
    @AppStorage("app_font_selection") private var selectedFont = AppFont.rounded.rawValue
    
    var body: some View {
        Form {
            Section(header: Text("App Font")) {
                Picker("Select Font", selection: $selectedFont) {
                    ForEach(AppFont.allCases) { font in
                        Text(font.rawValue).tag(font.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }
            
            Section(header: Text("Preview")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hero Title")
                        .font(DesignSystem.Typography.heroTitle)
                    
                    Text("This is a standard title")
                        .font(DesignSystem.Typography.title)
                    
                    Text("And a lovely subtitle")
                        .font(DesignSystem.Typography.subtitle)
                    
                    Text("This is standard body text. It shows how the font choice affects the general readability of paragraphs within the app.")
                        .font(DesignSystem.Typography.body)
                    
                    Text("Caption Text")
                        .font(DesignSystem.Typography.caption)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Typography Settings")
    }
}
