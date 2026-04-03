import math
from supabase import create_client, Client

# ==========================================
# === ROUTE AUDITOR & CLEANUP ===
# ==========================================
SUPABASE_URL = "https://qujkzrwrhrqejsqulohy.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1amt6cndyaHJxZWpzcXVsb2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTQzMDYsImV4cCI6MjA4ODU3MDMwNn0.mdB8rjht5QtGcYmeEbNmYDlXLdsHcH9jzxmTOi4S28E"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def haversine_distance(lat1, lon1, lat2, lon2):
    """
    Calculates the actual distance in kilometers between two GPS points 
    taking into account the curvature of the Earth.
    """
    R = 6371.0 # Earth radius in kilometers
    
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    
    a = math.sin(dLat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c

def audit_routes():
    print("🔍 Fetching all generated routes from Supabase...")
    response = supabase.table("mountain_routes").select("id, route_name, start_lat, start_lon, mountain_id").execute()
    routes = response.data
    
    if not routes:
        print("No routes found in the database.")
        return
        
    print(f"📊 Found {len(routes)} total routes. Checking their accuracy...")
    
    # Fetch the actual mountain coordinates to compare against
    mountain_ids = [r["mountain_id"] for r in routes]
    m_response = supabase.table("mountains").select("id, name, latitude, longitude").in_("id", mountain_ids).execute()
    mountains = {m["id"]: m for m in m_response.data}
    
    suspicious_routes = []
    
    for route in routes:
        mountain = mountains.get(route["mountain_id"])
        if not mountain:
            continue
            
        m_lat = mountain["latitude"]
        m_lon = mountain["longitude"]
        r_lat = route["start_lat"]
        r_lon = route["start_lon"]
        
        distance_km = haversine_distance(r_lat, r_lon, m_lat, m_lon)
        
        # If the start point is more than 35km away from the peak, it's definitely a glitch
        if distance_km > 35.0:
            suspicious_routes.append((route, mountain, distance_km))
            
    if not suspicious_routes:
        print("✅ All routes look perfect! No trailheads are further than 35km away.")
    else:
        print(f"\n⚠️ Found {len(suspicious_routes)} SUSPICIOUS routes with crazy distances:")
        for r, m, dist in suspicious_routes:
            print(f"   - {m['name']}: Trailhead is {dist:.1f} km away from summit!")
            
        print("\nThese usually happen if OpenStreetMap had bad data or OSRM got confused.")
        choice = input("Do you want to DELETE these broken routes so they can be skipped/regenerated later? (y/n): ")
        
        if choice.lower().strip() == 'y':
            for r, m, dist in suspicious_routes:
                supabase.table("mountain_routes").delete().eq("id", r["id"]).execute()
                print(f"🗑️ Deleted route for {m['name']}")
            print("✨ Cleanup complete!")
        else:
            print("No routes were deleted.")

if __name__ == "__main__":
    audit_routes()
