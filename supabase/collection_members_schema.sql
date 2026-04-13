-- ============================================
-- COLLECTION MEMBERS - Friend sharing for collections
-- ============================================

-- Add visibility column to collections if not exists
ALTER TABLE public.collections ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'private';

-- Collection Members table
CREATE TABLE IF NOT EXISTS public.collection_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'viewer' CHECK (role IN ('viewer', 'editor', 'admin')),
    invited_by UUID REFERENCES auth.users(id),
    joined_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(collection_id, user_id)
);

ALTER TABLE public.collection_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view their memberships" ON public.collection_members;
CREATE POLICY "Members can view their memberships"
ON public.collection_members FOR SELECT
USING (
    auth.uid() = user_id
    OR collection_id IN (SELECT id FROM public.collections WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Collection owners can manage members" ON public.collection_members;
CREATE POLICY "Collection owners can manage members"
ON public.collection_members FOR INSERT
WITH CHECK (
    collection_id IN (SELECT id FROM public.collections WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Owners or self can remove members" ON public.collection_members;
CREATE POLICY "Owners or self can remove members"
ON public.collection_members FOR DELETE
USING (
    auth.uid() = user_id
    OR collection_id IN (SELECT id FROM public.collections WHERE user_id = auth.uid())
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_collection_members_user ON public.collection_members(user_id);
CREATE INDEX IF NOT EXISTS idx_collection_members_collection ON public.collection_members(collection_id);

-- Update collections RLS to allow shared access
DROP POLICY IF EXISTS "Users can view own or shared collections" ON public.collections;
CREATE POLICY "Users can view own or shared collections"
ON public.collections FOR SELECT
USING (
    auth.uid() = user_id
    OR visibility = 'public'
    OR id IN (SELECT collection_id FROM public.collection_members WHERE user_id = auth.uid())
);
