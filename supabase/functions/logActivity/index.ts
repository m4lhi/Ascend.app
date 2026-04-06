import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Get the user from the authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response("Missing authorization header", { status: 401 });
    }

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authError || !user) {
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = await req.json();
    let { 
      distance_km, 
      elevation_m, 
      difficulty_level, // easy=1, moderate=2, hard=3, extreme=4
      activity_type,    // 'hiking', 'climbing', 'ski_tour', 'hut_overnight', 'prestige_peak'
      prestige_multiplier // 2.5 - 5.0 explicitly passed if it's a prestige peak
    } = payload;

    distance_km = parseFloat(distance_km || 0);
    elevation_m = parseFloat(elevation_m || 0);

    // 1. Anti Exploit
    if (distance_km < 1) return new Response(JSON.stringify({ error: "Distance too short (< 1km)" }), { status: 400 });
    if (elevation_m < 50) return new Response(JSON.stringify({ error: "Elevation too low (< 50m)" }), { status: 400 });

    // 2. Fetch User Profile
    const { data: profile, error: profileError } = await supabaseClient
      .from('ascend_profiles')
      .select('*')
      .eq('user_id', user.id)
      .single();

    let p = profile || {
      user_id: user.id,
      ascend_xp: 0,
      ascend_level: 1,
      ascend_tier: 'Bronze',
      ascend_subtier: 1,
      streak_days: 0,
      last_activity_date: null,
      daily_xp: 0,
      weekly_activity_types: [],
      prestige_mountains_completed: 0
    };

    // Calculate Dates for Daily/Streak Logic
    const now = new Date();
    const lastDate = p.last_activity_date ? new Date(p.last_activity_date) : null;
    let isNewDay = true;
    let isStreakContinues = false;

    if (lastDate) {
      const diffTime = Math.abs(now.getTime() - lastDate.getTime());
      const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
      
      if (diffDays === 0 && now.getDate() === lastDate.getDate()) {
        isNewDay = false;
        isStreakContinues = true;
      } else if (diffDays === 1 || (diffDays === 0 && now.getDate() !== lastDate.getDate())) {
        isStreakContinues = true;
        p.streak_days += 1;
      } else {
        p.streak_days = 1;
      }
    } else {
      p.streak_days = 1;
    }

    if (isNewDay) {
      p.daily_xp = 0;
    }

    // Weekly activity types logic (simplified for edge function: add if not present, reset handled elsewhere or just keep last N)
    if (!p.weekly_activity_types.includes(activity_type)) {
      p.weekly_activity_types.push(activity_type);
    }

    // 3. Modifier calculations before XP base
    if (activity_type === 'ski_tour') {
      elevation_m *= 2;
    }

    // 4. Base XP Calculation
    // XP = 8 * log10(distance_km + 1) * (1 + elevationGain_m / 1200) * (1 + difficulty / 6)
    let diffVal = difficulty_level || 2; 
    let baseXP = 8 * Math.log10(distance_km + 1) * (1 + elevation_m / 1200) * (1 + diffVal / 6);

    // 5. Activity Modifiers
    if (activity_type === 'prestige_peak') {
      let mult = Math.min(Math.max(parseFloat(prestige_multiplier) || 2.5, 2.5), 5.0);
      baseXP *= mult;
      p.prestige_mountains_completed += 1;
    }
    if (activity_type === 'climbing') {
      baseXP *= 1.6;
      baseXP += 20;
    }
    if (activity_type === 'hut_overnight') {
      baseXP += 25; // max 2 is simplified here to just +25
    }

    // 6. Multipliers
    // Diversity
    let uniqueTypesNum = p.weekly_activity_types.length;
    baseXP *= (1 + uniqueTypesNum * 0.1);

    // Streak
    let streakMultiplier = 1 + Math.min(p.streak_days * 0.02, 0.5);
    baseXP *= streakMultiplier;

    // 7. Anti-Exploit XP Caps
    // Repeat activity omitted for simplicity, but dailyXP cap applies:
    if (p.daily_xp >= 10000) {
      baseXP = 0;
    } else if (p.daily_xp >= 5000) {
      baseXP *= 0.5;
    }

    p.daily_xp += baseXP;
    p.ascend_xp += baseXP;

    // 8. Level Up Loop
    // XP_needed(level) = 50 * (level ^ 1.8)
    const getXpNeeded = (lvl: number) => 50 * Math.pow(lvl, 1.8);

    let xpNeeded = getXpNeeded(p.ascend_level);
    while (p.ascend_xp >= xpNeeded && p.ascend_level < 1000) {
      p.ascend_xp -= xpNeeded;
      p.ascend_level += 1;
      xpNeeded = getXpNeeded(p.ascend_level);
    }

    // 9. Tier and Subtier Logic
    // Bronze: 1–150, Silber: 151–300, Gold: 301–500, Platin: 501–800, Obsidian: 801–1000
    // Obsidian Requirements: prestige >= 25, weekly >= 3. Else cap at Platin III (Level 800)
    
    if (p.ascend_level >= 800) {
      if (p.prestige_mountains_completed >= 25 && p.weekly_activity_types.length >= 3) {
        // Obsidian unlocked!
      } else {
        // Cap
        p.ascend_level = 800;
        p.ascend_xp = 0;
      }
    }

    let tierLabel = 'Bronze';
    let subtierLabel = 1;
    let level = p.ascend_level;

    if (level <= 150) {
      tierLabel = 'Bronze';
      subtierLabel = level <= 50 ? 1 : level <= 100 ? 2 : 3;
    } else if (level <= 300) {
      tierLabel = 'Silver';  // or Silber
      subtierLabel = level <= 200 ? 1 : level <= 250 ? 2 : 3;
    } else if (level <= 500) {
      tierLabel = 'Gold';
      subtierLabel = level <= 366 ? 1 : level <= 433 ? 2 : 3;
    } else if (level <= 800) {
      tierLabel = 'Platinum'; // or Platin
      subtierLabel = level <= 600 ? 1 : level <= 700 ? 2 : 3;
    } else {
      tierLabel = 'Obsidian';
      subtierLabel = level <= 866 ? 1 : level <= 933 ? 2 : 3;
    }

    p.ascend_tier = tierLabel;
    p.ascend_subtier = subtierLabel;
    p.last_activity_date = now.toISOString();

    // 10. Save to DB
    const { error: upsertError } = await supabaseClient
      .from('ascend_profiles')
      .upsert(p);

    if (upsertError) {
      return new Response(JSON.stringify({ error: upsertError.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ 
      success: true, 
      xp_awarded: baseXP,
      new_level: p.ascend_level,
      new_tier: p.ascend_tier,
      new_subtier: p.ascend_subtier
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
