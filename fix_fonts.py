import os
import re

dir_path = "Ascent"

regex_size_weight_design = re.compile(r'\.font\(\s*\.system\(\s*size:\s*([\d\.]+)\s*,\s*weight:\s*\.([\w]+)\s*(?:,\s*design:\s*\.[\w]+)?\s*\)\s*\)')
regex_size_design = re.compile(r'\.font\(\s*\.system\(\s*size:\s*([\d\.]+)\s*(?:,\s*design:\s*\.[\w]+)?\s*\)\s*\)')
regex_style_design = re.compile(r'\.font\(\s*\.system\(\s*\.([\w]+)\s*(?:,\s*design:\s*\.[\w]+)?\s*\)\s*\)')

count = 0
for root, dirs, files in os.walk(dir_path):
    for filename in files:
        if filename.endswith(".swift") and filename != "DesignSystem.swift" and filename != "FontSettingsView.swift":
            filepath = os.path.join(root, filename)
            with open(filepath, 'r') as f:
                content = f.read()

            new_content = regex_size_weight_design.sub(r'.font(DesignSystem.Typography.appFont(size: \1, weight: .\2))', content)
            new_content = regex_size_design.sub(r'.font(DesignSystem.Typography.appFont(size: \1))', new_content)
            new_content = regex_style_design.sub(r'.font(DesignSystem.Typography.appFont(style: .\1))', new_content)

            if new_content != content:
                with open(filepath, 'w') as f:
                    f.write(new_content)
                count += 1

print(f"Modified {count} files")
