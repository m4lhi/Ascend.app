import os
import time
import requests
import math
from supabase import create_client, Client

# ==========================================
# === ROUTE FETCHER (OSRM DEMO)
# ==========================================
# Make sure to pip install supabase requests
# Replace string values with your credentials

SUPABASE_URL = "https://qujkzrwrhrqejsqulohy.supabase.co"
# You MUST replace this with your actual anon/service key or set via .env
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1amt6cndyaHJxZWpzcXVsb2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTQzMDYsImV4cCI6MjA4ODU3MDMwNn0.mdB8rjht5QtGcYmeEbNmYDlXLdsHcH9jzxmTOi4S28E"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Free OSRM API Demo server (rate limited to ~1 request per second)
# For production/70k peaks, consider self-hosting OSRM or OpenRouteService.
OSRM_BASE_URL = "http://router.project-osrm.org/route/v1/foot/"

def fetch_walking_route(start_lon, start_lat, end_lon, end_lat):
    """
    Fetches a walking route from OSRM and returns the polyline.
    """
    url = f"{OSRM_BASE_URL}{start_lon},{start_lat};{end_lon},{end_lat}?overview=full"
    
    try:
        response = requests.get(url, timeout=5)
        data = response.json()
        
        if data.get("code") == "Ok":
            # The encoded polyline geometry
            return data["routes"][0]["geometry"]
        else:
            print(f"OSRM Error: {data.get('code')}")
            return None
    except Exception as e:
        print(f"Request failed: {e}")
        return None

def find_start_point(peak_lat, peak_lon, retries=3):
    """
    Uses OpenStreetMap (Overpass API) to find the nearest parking lot or alpine hut 
    within a 30km radius of the peak.
    """
    overpass_url = "http://overpass-api.de/api/interpreter"
    overpass_query = f"""
    [out:json];
    (
      nwr["amenity"="parking"](around:30000, {peak_lat}, {peak_lon});
      nwr["tourism"="alpine_hut"](around:30000, {peak_lat}, {peak_lon});
      nwr["highway"="trailhead"](around:30000, {peak_lat}, {peak_lon});
    );
    out center tags;
    """
    
    try:
        response = requests.post(overpass_url, data={'data': overpass_query}, timeout=15)
        
        if response.status_code == 429:
            print("⚠️ Overpass API rate limit hit. Sleeping for 15 seconds...")
            time.sleep(15)
            if retries > 0:
                return find_start_point(peak_lat, peak_lon, retries - 1)
            return peak_lat - 0.02, peak_lon
            
        data = response.json()
        elements = data.get('elements', [])
        
        if elements:
            parkings = []
            huts = []
            
            for el in elements:
                lat = el.get('lat') or el.get('center', {}).get('lat')
                lon = el.get('lon') or el.get('center', {}).get('lon')
                tags = el.get('tags', {})
                
                if lat and lon:
                    # Simple geographic distance calculation (1 degree = ~111km)
                    dist = math.hypot(lat - peak_lat, lon - peak_lon)
                    
                    # IGNORE any amenity that is too close to the summit (< ~1km / 0.009 deg)
                    # This prevents picking a summit cross or a hut that is directly on the peak.
                    if dist < 0.009:
                        continue
                        
                    if tags.get('amenity') == 'parking' or tags.get('highway') == 'trailhead':
                        parkings.append((dist, lat, lon))
                    else:
                        huts.append((dist, lat, lon))
                        
            # PRIORITY 1: Parking lots & Trailheads (usually in the valley)
            if parkings:
                parkings.sort(key=lambda x: x[0])
                return parkings[0][1], parkings[0][2]
                
            # PRIORITY 2: Alpine Huts (Fallback)
            if huts:
                # We sort by distance. Since we filtered out < 1km, it will pick the closest
                # hut that is at least a reasonable distance away.
                huts.sort(key=lambda x: x[0])
                return huts[0][1], huts[0][2]
                
    except Exception as e:
        print(f"⚠️ Overpass API error: {e}")
        if "Expecting value" in str(e) or "JSON" in str(e):
            print("Rate limit or server error. Sleeping 10s before retry...")
            time.sleep(10)
            if retries > 0:
                return find_start_point(peak_lat, peak_lon, retries - 1)
        
    # Fallback if no parking/hut is mapped nearby:
    # Approx 2km offset south to generate a routing line
    return peak_lat - 0.02, peak_lon

def process_mountains():
    print("Fetching top priority peaks without routes from Supabase...")
    
    # 1. Fetch all mountain_ids that ALREADY have a route so we don't create duplicates
    try:
        existing_routes = supabase.table("mountain_routes").select("mountain_id").execute()
        completed_ids = {r["mountain_id"] for r in existing_routes.data}
    except Exception as e:
        print(f"Could not fetch existing routes (Table might be empty/missing): {e}")
        completed_ids = set()
    
    # SMART STRATEGY: Prioritize Prestige Peaks and highest mountains first.
    # We fetch a larger batch, then filter out the ones we already did.
    response = supabase.table("mountains") \
        .select("id, name, latitude, longitude, isPrestigePeak, elevation") \
        .not_.is_("latitude", "null") \
        .not_.is_("longitude", "null") \
        .order("isPrestigePeak", desc=True) \
        .order("elevation", desc=True) \
        .limit(1000) \
        .execute()
        
    all_peaks = response.data
    
    if not all_peaks:
        print("No peaks found.")
        return

    # Filter out mountains that already have routes, and limit to processing 100 at a time
    peaks = [p for p in all_peaks if p["id"] not in completed_ids][:100]
    
    if not peaks:
        print("All top peaks in this batch already have routes!")
        return

    print(f"Generating routes for {len(peaks)} new peaks...")
    
    for peak in peaks:
        mountain_id = peak["id"]
        peak_lat, peak_lon = peak["latitude"], peak["longitude"]
        is_prestige = peak.get("isPrestigePeak", False)
        
        # Determine the realistic start point using OpenStreetMap data
        print(f"Finding trailhead for {peak['name']} ...")
        trailhead_lat, trailhead_lon = find_start_point(peak_lat, peak_lon)
        
        print(f"Fetching route for {peak['name']} ...")
        polyline = fetch_walking_route(trailhead_lon, trailhead_lat, peak_lon, peak_lat)
        
        if polyline:
            route_data = {
                "mountain_id": mountain_id,
                "route_name": f"{peak['name']} Standard Route",
                "start_lat": trailhead_lat,
                "start_lon": trailhead_lon,
                "route_polyline": polyline
            }
            
            # Immediately push to Supabase so we don't lose data if stopped early
            try:
                supabase.table("mountain_routes").insert(route_data).execute()
                print(f"✅ Saved route for {peak['name']} to database.")
            except Exception as e:
                print(f"❌ Failed to insert {peak['name']} to Supabase: {e}")
            
        # Respect API Rate limits (OSRM and Overpass)
        time.sleep(4.0)
        
    print("Finished processing batch!")

if __name__ == "__main__":
    process_mountains()
