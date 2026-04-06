-- Create ascend profiles table
CREATE TABLE IF NOT EXISTS public.ascend_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    ascend_xp FLOAT DEFAULT 0,
    ascend_level INT DEFAULT 1,
    ascend_tier TEXT DEFAULT 'Bronze',
    ascend_subtier INT DEFAULT 1,
    streak_days INT DEFAULT 0,
    last_activity_date TIMESTAMPTZ,
    daily_xp FLOAT DEFAULT 0,
    weekly_activity_types TEXT[] DEFAULT '{}',
    prestige_mountains_completed INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.ascend_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own ascend profile"
ON public.ascend_profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own ascend profile"
ON public.ascend_profiles FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own ascend profile"
ON public.ascend_profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Trigger to auto-create profile on user creation
CREATE OR REPLACE FUNCTION public.handle_new_ascend_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.ascend_profiles (user_id)
  VALUES (new.id);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Uncomment the next line if you want to automatically trigger this on signup
-- CREATE TRIGGER on_auth_user_created_ascend
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE PROCEDURE public.handle_new_ascend_profile();

-- Create mountain routes table for offline routing
CREATE TABLE IF NOT EXISTS public.mountain_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mountain_id UUID NOT NULL REFERENCES public.mountains(id) ON DELETE CASCADE,
    route_name TEXT NOT NULL,
    start_lat DOUBLE PRECISION NOT NULL,
    start_lon DOUBLE PRECISION NOT NULL,
    route_polyline TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for mountain_routes
ALTER TABLE public.mountain_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view mountain routes"
ON public.mountain_routes FOR SELECT
USING (true);

-- You can restrict this to admins/service roles if needed for insertion
CREATE POLICY "Admins/Service keys can insert mountain routes"
ON public.mountain_routes FOR INSERT
WITH CHECK (true);

-- ============================================
-- Add route_polyline to tours table for map display in social feed
-- ============================================
ALTER TABLE public.tours ADD COLUMN IF NOT EXISTS route_polyline TEXT;
