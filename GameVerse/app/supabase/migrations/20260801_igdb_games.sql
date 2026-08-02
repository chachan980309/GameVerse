alter table public.user_games
  add column if not exists igdb_id bigint,
  add column if not exists cover_url text,
  add column if not exists game_source text not null default 'igdb';

create index if not exists user_games_igdb_id_idx
  on public.user_games(igdb_id);

create unique index if not exists user_games_user_igdb_unique
  on public.user_games(user_id, igdb_id)
  where igdb_id is not null;
