-- ============================================
-- ROUTE SAVING SYSTEM - Komoot-inspired
-- Tables: saved_routes (enhanced), route_folders, route_folder_members, route_folder_routes
-- ============================================

-- 1. Enhanced saved_routes table (drop-and-recreate or alter)
-- If the table already exists, use ALTER statements instead.

CREATE TABLE IF NOT EXISTS public.saved_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    mountain_ids UUID[] DEFAULT '{}',
    route_polyline TEXT,                    -- encoded [[lat,lon,alt],...] JSON
    cover_image_url TEXT,
    total_distance_km DOUBLE PRECISION DEFAULT 0,
    total_elevation_gain INT DEFAULT 0,
    estimated_duration_minutes INT DEFAULT 0,
    difficulty TEXT DEFAULT 'Medium',
    visibility TEXT DEFAULT 'private' CHECK (visibility IN ('private', 'friends', 'public')),
    tags TEXT[] DEFAULT '{}',
    sport_type TEXT DEFAULT 'hiking' CHECK (sport_type IN ('hiking', 'trail_running', 'mountaineering', 'ski_touring', 'climbing')),
    is_completed BOOLEAN DEFAULT false,     -- user has done this route
    rating INT CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add columns if table already exists (safe to run multiple times)
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS route_polyline TEXT;
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'private';
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS sport_type TEXT DEFAULT 'hiking';
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS is_completed BOOLEAN DEFAULT false;
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS rating INT;
ALTER TABLE public.saved_routes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- RLS for saved_routes
ALTER TABLE public.saved_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own routes" ON public.saved_routes;
CREATE POLICY "Users can view own routes"
ON public.saved_routes FOR SELECT
USING (
    auth.uid() = user_id
    OR visibility = 'public'
    OR (visibility = 'friends' AND user_id IN (
        SELECT friend_id FROM public.friendships WHERE user_id = auth.uid() AND status = 'accepted'
    ))
);

DROP POLICY IF EXISTS "Users can insert own routes" ON public.saved_routes;
CREATE POLICY "Users can insert own routes"
ON public.saved_routes FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own routes" ON public.saved_routes;
CREATE POLICY "Users can update own routes"
ON public.saved_routes FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own routes" ON public.saved_routes;
CREATE POLICY "Users can delete own routes"
ON public.saved_routes FOR DELETE
USING (auth.uid() = user_id);


-- 2. Route Folders (like Komoot Collections)
CREATE TABLE IF NOT EXISTS public.route_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    cover_image_url TEXT,
    visibility TEXT DEFAULT 'private' CHECK (visibility IN ('private', 'shared', 'public')),
    color TEXT DEFAULT '#2680FF',           -- folder accent color
    icon TEXT DEFAULT 'folder.fill',        -- SF Symbol name
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.route_folders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Folder owners and members can view" ON public.route_folders;
CREATE POLICY "Folder owners and members can view"
ON public.route_folders FOR SELECT
USING (
    auth.uid() = owner_id
    OR visibility = 'public'
    OR id IN (SELECT folder_id FROM public.route_folder_members WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Owners can insert folders" ON public.route_folders;
CREATE POLICY "Owners can insert folders"
ON public.route_folders FOR INSERT
WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update folders" ON public.route_folders;
CREATE POLICY "Owners can update folders"
ON public.route_folders FOR UPDATE
USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can delete folders" ON public.route_folders;
CREATE POLICY "Owners can delete folders"
ON public.route_folders FOR DELETE
USING (auth.uid() = owner_id);


-- 3. Route Folder Members (sharing system)
CREATE TABLE IF NOT EXISTS public.route_folder_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folder_id UUID NOT NULL REFERENCES public.route_folders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'viewer' CHECK (role IN ('viewer', 'editor', 'admin')),
    invited_by UUID REFERENCES auth.users(id),
    joined_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(folder_id, user_id)
);

ALTER TABLE public.route_folder_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view memberships" ON public.route_folder_members;
CREATE POLICY "Members can view memberships"
ON public.route_folder_members FOR SELECT
USING (
    auth.uid() = user_id
    OR folder_id IN (SELECT id FROM public.route_folders WHERE owner_id = auth.uid())
);

DROP POLICY IF EXISTS "Folder owners can manage members" ON public.route_folder_members;
CREATE POLICY "Folder owners can manage members"
ON public.route_folder_members FOR INSERT
WITH CHECK (
    folder_id IN (SELECT id FROM public.route_folders WHERE owner_id = auth.uid())
);

DROP POLICY IF EXISTS "Folder owners can remove members" ON public.route_folder_members;
CREATE POLICY "Folder owners can remove members"
ON public.route_folder_members FOR DELETE
USING (
    auth.uid() = user_id
    OR folder_id IN (SELECT id FROM public.route_folders WHERE owner_id = auth.uid())
);


-- 4. Route-Folder junction table (many-to-many)
CREATE TABLE IF NOT EXISTS public.route_folder_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folder_id UUID NOT NULL REFERENCES public.route_folders(id) ON DELETE CASCADE,
    route_id UUID NOT NULL REFERENCES public.saved_routes(id) ON DELETE CASCADE,
    added_by UUID REFERENCES auth.users(id),
    added_at TIMESTAMPTZ DEFAULT now(),
    sort_order INT DEFAULT 0,
    UNIQUE(folder_id, route_id)
);

ALTER TABLE public.route_folder_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Folder members can view routes" ON public.route_folder_routes;
CREATE POLICY "Folder members can view routes"
ON public.route_folder_routes FOR SELECT
USING (
    folder_id IN (
        SELECT id FROM public.route_folders WHERE owner_id = auth.uid()
        UNION
        SELECT folder_id FROM public.route_folder_members WHERE user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Editors can add routes to folders" ON public.route_folder_routes;
CREATE POLICY "Editors can add routes to folders"
ON public.route_folder_routes FOR INSERT
WITH CHECK (
    folder_id IN (
        SELECT id FROM public.route_folders WHERE owner_id = auth.uid()
        UNION
        SELECT folder_id FROM public.route_folder_members WHERE user_id = auth.uid() AND role IN ('editor', 'admin')
    )
);

DROP POLICY IF EXISTS "Editors can remove routes from folders" ON public.route_folder_routes;
CREATE POLICY "Editors can remove routes from folders"
ON public.route_folder_routes FOR DELETE
USING (
    folder_id IN (
        SELECT id FROM public.route_folders WHERE owner_id = auth.uid()
        UNION
        SELECT folder_id FROM public.route_folder_members WHERE user_id = auth.uid() AND role IN ('editor', 'admin')
    )
);


-- 5. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_saved_routes_user ON public.saved_routes(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_routes_visibility ON public.saved_routes(visibility);
CREATE INDEX IF NOT EXISTS idx_route_folders_owner ON public.route_folders(owner_id);
CREATE INDEX IF NOT EXISTS idx_route_folder_members_user ON public.route_folder_members(user_id);
CREATE INDEX IF NOT EXISTS idx_route_folder_members_folder ON public.route_folder_members(folder_id);
CREATE INDEX IF NOT EXISTS idx_route_folder_routes_folder ON public.route_folder_routes(folder_id);
CREATE INDEX IF NOT EXISTS idx_route_folder_routes_route ON public.route_folder_routes(route_id);


-- 6. Helper RPC: Search users by username for sharing
CREATE OR REPLACE FUNCTION public.search_users_for_sharing(search_term TEXT)
RETURNS TABLE(id UUID, username TEXT, handle TEXT, avatar_url TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.username, p.handle, p.avatar_url
    FROM public.profiles p
    WHERE (p.username ILIKE '%' || search_term || '%' OR p.handle ILIKE '%' || search_term || '%')
    AND p.id != auth.uid()
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 7. Helper RPC: Get folder with member count and route count
CREATE OR REPLACE FUNCTION public.get_folder_details(p_folder_id UUID)
RETURNS TABLE(
    folder_id UUID,
    folder_name TEXT,
    description TEXT,
    cover_image_url TEXT,
    visibility TEXT,
    color TEXT,
    icon TEXT,
    owner_id UUID,
    owner_username TEXT,
    member_count BIGINT,
    route_count BIGINT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.id,
        f.name,
        f.description,
        f.cover_image_url,
        f.visibility,
        f.color,
        f.icon,
        f.owner_id,
        p.username,
        (SELECT COUNT(*) FROM public.route_folder_members m WHERE m.folder_id = f.id),
        (SELECT COUNT(*) FROM public.route_folder_routes r WHERE r.folder_id = f.id),
        f.created_at
    FROM public.route_folders f
    LEFT JOIN public.profiles p ON p.id = f.owner_id
    WHERE f.id = p_folder_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
