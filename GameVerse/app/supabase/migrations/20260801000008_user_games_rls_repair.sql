-- Permite que cada usuario autenticado gestione únicamente sus propios juegos.
alter table public.user_games enable row level security;

drop policy if exists "Users manage their own games" on public.user_games;
drop policy if exists "Users insert their own games" on public.user_games;
drop policy if exists "Users update their own games" on public.user_games;
drop policy if exists "Users delete their own games" on public.user_games;

create policy "Users insert their own games"
  on public.user_games for insert to authenticated
  with check (auth.uid() = user_id);

create policy "Users update their own games"
  on public.user_games for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users delete their own games"
  on public.user_games for delete to authenticated
  using (auth.uid() = user_id);
