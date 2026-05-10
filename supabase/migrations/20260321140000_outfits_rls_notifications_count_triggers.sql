-- P0: Fix outfits SELECT leak, tighten notifications INSERT, dedupe fire_count / outfit_count triggers.
-- See docs/SUPABASE_LAUNCH_REVIEW.md §5.2–5.6, docs/FINAL_ACTION_ITEMS.md M1–M4.

-- -----------------------------------------------------------------------------
-- 1) outfits RLS — root cause: permissive policies OR together; `outfits_read`
--    (deleted_at IS NULL only) exposed friends-only rows to any authenticated user.
--    Keep existing "Public…" + "Users can view own…"; drop leak; add mutual-follow
--    read for visibility = friends (matches app friends feed: mutual follows).
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "outfits_read" ON public.outfits;

CREATE POLICY "Mutual followers can view friends-only outfits"
  ON public.outfits
  FOR SELECT
  USING (
    deleted_at IS NULL
    AND visibility = 'friends'::text
    AND auth.uid() IS NOT NULL
    AND user_id <> auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.follows f_fwd
      WHERE f_fwd.follower_id = auth.uid()
        AND f_fwd.following_id = outfits.user_id
    )
    AND EXISTS (
      SELECT 1
      FROM public.follows f_rev
      WHERE f_rev.follower_id = outfits.user_id
        AND f_rev.following_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 2) notifications — root cause: "Users insert notifications" WITH CHECK (true)
--    allowed arbitrary user_id. Trigger inserts use SECURITY DEFINER and bypass RLS;
--    client inserts remain governed by "System can insert notifications"
--    (auth.uid() = from_user_id).
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users insert notifications" ON public.notifications;

-- -----------------------------------------------------------------------------
-- 3) fires — root cause: trg_fire_inc/dec AND two triggers calling update_fire_count()
--    per row → triple bump. Keep a single INSERT|DELETE trigger on update_fire_count();
--    keep notify_on_fire separate.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS after_fire_insert ON public.fires;
DROP TRIGGER IF EXISTS after_fire_delete ON public.fires;
DROP TRIGGER IF EXISTS trg_fire_count ON public.fires;

-- -----------------------------------------------------------------------------
-- 4) outfits / profiles.outfit_count — root cause: trg_outfit_inc + duplicate
--    update_outfit_count triggers + sync_outfit_count on insert/update(deleted_at).
--    Keep only sync_outfit_count (SECURITY DEFINER, symmetric +1 insert / -1 soft-delete).
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS after_outfit_insert ON public.outfits;
DROP TRIGGER IF EXISTS on_outfit_change ON public.outfits;
DROP TRIGGER IF EXISTS trg_outfit_count ON public.outfits;

-- -----------------------------------------------------------------------------
-- 5) One-off reconciliation after historical over-increments
-- -----------------------------------------------------------------------------
UPDATE public.outfits AS o
SET fire_count = s.c
FROM (
  SELECT outfit_id, count(*)::integer AS c
  FROM public.fires
  GROUP BY outfit_id
) AS s
WHERE o.id = s.outfit_id;

UPDATE public.outfits AS o
SET fire_count = 0
WHERE NOT EXISTS (SELECT 1 FROM public.fires AS f WHERE f.outfit_id = o.id);

UPDATE public.profiles AS p
SET outfit_count = coalesce(
  (
    SELECT count(*)::integer
    FROM public.outfits AS o
    WHERE o.user_id = p.id
      AND o.deleted_at IS NULL
  ),
  0
);
