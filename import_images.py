import requests, time
from supabase import create_client

supabase = create_client(
    "https://qujkzrwrhrqejsqulohy.supabase.co",
    "sb_publishable_tzrr2n1ElsAYIl7jAzWAiw_BT7DsRsv"
)

def get_wikimedia_image(query):
    try:
        response = requests.get(
            "https://en.wikipedia.org/w/api.php",
            params={
                "action": "query",
                "titles": query,
                "prop": "pageimages",
                "pithumbsize": 1200,
                "format": "json",
                "redirects": 1
            },
            timeout=10
        )
        pages = response.json().get("query", {}).get("pages", {})
        for page_id, page in pages.items():
            if page_id == "-1":
                continue
            thumb = page.get("thumbnail", {})
            if thumb:
                return thumb.get("source")
        return None
    except:
        return None

# Fetch all mountains without images, prestige first then by elevation
result = supabase.table("mountains")    .select("id,name,country,elevation")    .or_("imageUrl.is.null,imageUrl.eq.")    .order("isPrestigePeak", desc=True)    .order("elevation", desc=True)    .execute()

peaks = result.data
print(f"Found {len(peaks)} mountains without images")

updated = 0
not_found = 0

for i, peak in enumerate(peaks):
    name = peak["name"]
    country = peak.get("country", "")
    elevation = peak.get("elevation", 0)
    
    print(f"[{i+1}/{len(peaks)}] {name} ({country}, {elevation}m)...")
    
    image_url = get_wikimedia_image(f"{name} mountain {country}")
    if not image_url:
        image_url = get_wikimedia_image(name)
    
    if image_url:
        supabase.table("mountains")            .update({"imageUrl": image_url})            .eq("id", peak["id"])            .execute()
        print(f"  Found")
        updated += 1
    else:
        not_found += 1
        print(f"  Not found")
    
    # Small delay to avoid rate limiting
    time.sleep(0.3)
    
    # Progress every 100
    if (i + 1) % 100 == 0:
        print(f"Progress: {updated} updated, {not_found} not found so far")

print(f"DONE: {updated} updated, {not_found} not found")
