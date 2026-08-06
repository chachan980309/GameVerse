create table if not exists public.user_games (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  game_name text not null check (char_length(trim(game_name)) > 0),
  platform text,
  rank text,
  hours_played integer not null default 0 check (hours_played >= 0),
  is_favorite boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.user_games enable row level security;

drop policy if exists "Anyone can view user games" on public.user_games;
drop policy if exists "Users manage their own games" on public.user_games;

create policy "Anyone can view user games"
  on public.user_games for select using (true);

create policy "Users manage their own games"
  on public.user_games for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
