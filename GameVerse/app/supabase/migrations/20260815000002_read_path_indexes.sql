-- Covers the remaining bounded read paths introduced by the production
-- client. This migration is additive and safe to run after 20260815000001.

-- A user's library is displayed with favorites first, then newest entries.
create index if not exists user_games_user_favorite_created_idx
  on public.user_games (user_id, is_favorite desc, created_at desc);

-- The dashboard counts today's comments for the signed-in user.
create index if not exists comments_user_created_at_idx
  on public.comments (user_id, created_at desc);
