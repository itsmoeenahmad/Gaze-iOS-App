-- Friend accept creates two follow rows: (requester → accepter) and (accepter → requester).
-- The first INSERT uses follower_id = requester; only the accepter is authenticated, so the
-- default policy auth.uid() = follower_id rejects it. Allow that row when an accepted
-- friend_request exists from requester to accepter (from_user_id → to_user_id).

DROP POLICY IF EXISTS "follows_insert" ON public.follows;

CREATE POLICY "follows_insert" ON public.follows
FOR INSERT
WITH CHECK (
  auth.uid() = follower_id
  OR (
    auth.uid() = following_id
    AND EXISTS (
      SELECT 1
      FROM public.friend_requests fr
      WHERE fr.status = 'accepted'
        AND fr.from_user_id = follower_id
        AND fr.to_user_id = following_id
    )
  )
);
