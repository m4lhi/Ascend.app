import sys
with open('/Users/philip/Documents/Ascend Main/Ascent/Info.plist', 'r') as f:
    text = f.read()
if 'UIAppFonts' not in text:
    text = text.replace('<key>SupabaseURL</key>', '<key>UIAppFonts</key>\n\t<array>\n\t\t<string>Barlow-Regular.ttf</string>\n\t\t<string>Barlow-Bold.ttf</string>\n\t\t<string>Barlow-Medium.ttf</string>\n\t\t<string>Barlow-SemiBold.ttf</string>\n\t</array>\n\t<key>SupabaseURL</key>')
    with open('/Users/philip/Documents/Ascend Main/Ascent/Info.plist', w') as f:
        f.write(text)
