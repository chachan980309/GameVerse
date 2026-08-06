-- Add game poster, hero and background image URL columns to public.tournaments table
alter table public.tournaments
  add column if not exists game_poster_url text,
  add column if not exists game_hero_url text,
  add column if not exists game_background_url text;

-- Create index for faster querying
create index if not exists tournaments_game_image_resolution_idx
  on public.tournaments (game_poster_url, game_hero_url, game_background_url);
