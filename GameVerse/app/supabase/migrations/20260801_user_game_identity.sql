alter table public.user_games
  add column if not exists gamer_tag text,
  add column if not exists logo_url text;
