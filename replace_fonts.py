import os
import re

directory = "Ascent"

# Regex patterns
# 1. .font(.system(size: 14, weight: .bold, design: .rounded)) -> .font(.app(size: 14, weight: .bold))
# 2. .font(.system(size: 14, weight: .bold)) -> .font(.app(size: 14, weight: .bold))
# 3. .font(.system(size: 14, design: .rounded)) -> .font(.app(size: 14))
# 4. .font(.system(size: 14)) -> .font(.app(size: 14))
# 5. .font(.system(.headline, design: .rounded)) -> .font(.app(.headline))
# 6. .font(.system(.headline)) -> .font(.app(.headline))

def rewrite_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
        
    orig_content = content
    
    # 1 & 2
    content = re.sub(
        r'\.font\(\s*\.system\(\s*size:\s*([0-9.]+)\s*,\s*weight:\s*\.([a-zA-Z0-9_]+)\s*(?:,\s*design:\s*\.[a-zA-Z0-9_]+)?\s*\)\s*\)',
        r'.font(.app(size: \1, weight: .\2))',
        content
    )
    
    # 3 & 4
    content = re.sub(
        r'\.font\(\s*\.system\(\s*size:\s*([0-9.]+)\s*(?:,\s*design:\s*\.[a-zA-Z0-9_]+)?\s*\)\s*\)',
        r'.font(.app(size: \1))',
        content
    )
    
    # 5 & 6 (Styles like .headline)
    content = re.sub(
        r'\.font\(\s*\.system\(\s*\.([a-zA-Z0-9_]+)\s*(?:,\s*design:\s*\.[a-zA-Z0-9_]+)?\s*\)\s*\)',
        r'.font(.app(.\1))',
        content
    )
    
    if content != orig_content:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

changed_files = 0
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith(".swift"):
            path = os.path.join(root, file)
            if rewrite_file(path):
                changed_files += 1

print(f"Changed {changed_files} files.")
