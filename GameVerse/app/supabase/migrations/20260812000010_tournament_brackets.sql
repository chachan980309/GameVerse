-- Brackets persistentes: se generan al iniciar un torneo de eliminación simple.
create table if not exists public.tournament_matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  round_number integer not null check (round_number >= 1),
  match_number integer not null check (match_number >= 1),
  player_one_id uuid references public.profiles(id) on delete set null,
  player_two_id uuid references public.profiles(id) on delete set null,
  winner_id uuid references public.profiles(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'completed')),
  next_match_id uuid references public.tournament_matches(id) on delete set null,
  next_slot smallint check (next_slot in (1, 2)),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (tournament_id, round_number, match_number)
);

create index if not exists tournament_matches_bracket_idx
  on public.tournament_matches (tournament_id, round_number, match_number);

alter table public.tournament_matches enable row level security;

drop policy if exists "Authenticated users can read tournament matches" on public.tournament_matches;
create policy "Authenticated users can read tournament matches"
on public.tournament_matches for select to authenticated using (true);

-- Inserta un ganador en el siguiente partido y continúa las victorias por bye.
create or replace function public.propagate_tournament_winner(match_id uuid, player_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_match public.tournament_matches;
  next_match public.tournament_matches;
begin
  select * into current_match from public.tournament_matches where id = match_id for update;
  if current_match.id is null then return; end if;

  update public.tournament_matches
  set winner_id = player_id, status = 'completed', completed_at = now()
  where id = current_match.id and winner_id is null;

  if current_match.next_match_id is not null then
    update public.tournament_matches
    set player_one_id = case when current_match.next_slot = 1 then player_id else player_one_id end,
        player_two_id = case when current_match.next_slot = 2 then player_id else player_two_id end
    where id = current_match.next_match_id;
  else
    update public.tournaments set status = 'finished' where id = current_match.tournament_id;
  end if;

end;
$$;

create or replace function public.initialize_tournament_bracket(target_tournament_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  tournament_row public.tournaments;
  participant_ids uuid[];
  participant_count integer;
  bracket_size integer := 2;
  total_rounds integer;
  round_no integer;
  match_no integer;
  matches_in_round integer;
  current_match_id uuid;
  next_id uuid;
  seed_index integer;
begin
  select * into tournament_row from public.tournaments where id = target_tournament_id for update;
  if tournament_row.id is null then raise exception 'Torneo no encontrado'; end if;
  if tournament_row.creator_id <> auth.uid()
    and not exists (select 1 from public.profiles where id = auth.uid() and role = 'Admin') then
    raise exception 'Solo el organizador puede iniciar el torneo';
  end if;
  if tournament_row.type <> 'single_elimination' then
    raise exception 'Las llaves automáticas están disponibles actualmente para eliminación simple';
  end if;
  if exists (select 1 from public.tournament_matches where tournament_id = target_tournament_id) then
    raise exception 'La llave ya fue creada';
  end if;

  select array_agg(user_id order by random()) into participant_ids
  from public.tournament_participants where tournament_id = target_tournament_id;
  participant_count := coalesce(array_length(participant_ids, 1), 0);
  if participant_count < 2 then raise exception 'Se necesitan al menos 2 participantes'; end if;

  while bracket_size < participant_count loop bracket_size := bracket_size * 2; end loop;
  total_rounds := ceil(log(2, bracket_size::numeric))::integer;

  for round_no in 1..total_rounds loop
    matches_in_round := bracket_size / power(2, round_no)::integer;
    for match_no in 1..matches_in_round loop
      insert into public.tournament_matches (tournament_id, round_number, match_number)
      values (target_tournament_id, round_no, match_no);
    end loop;
  end loop;

  for round_no in 1..(total_rounds - 1) loop
    matches_in_round := bracket_size / power(2, round_no)::integer;
    for match_no in 1..matches_in_round loop
      select id into current_match_id from public.tournament_matches
      where tournament_id = target_tournament_id and round_number = round_no and match_number = match_no;
      select id into next_id from public.tournament_matches
      where tournament_id = target_tournament_id and round_number = round_no + 1
        and match_number = ((match_no + 1) / 2)::integer;
      update public.tournament_matches set next_match_id = next_id,
        next_slot = case when match_no % 2 = 1 then 1 else 2 end
      where id = current_match_id;
    end loop;
  end loop;

  for seed_index in 1..bracket_size loop
    update public.tournament_matches
    set player_one_id = case when seed_index % 2 = 1 then participant_ids[seed_index] else player_one_id end,
        player_two_id = case when seed_index % 2 = 0 then participant_ids[seed_index] else player_two_id end
    where tournament_id = target_tournament_id and round_number = 1
      and match_number = ((seed_index + 1) / 2)::integer;
  end loop;

  update public.tournaments set status = 'in_progress' where id = target_tournament_id;

  -- Propaga los byes de la primera ronda.
  for current_match_id in select id from public.tournament_matches
    where tournament_id = target_tournament_id and round_number = 1
      and ((player_one_id is not null and player_two_id is null)
        or (player_one_id is null and player_two_id is not null))
  loop
    select * into tournament_row from public.tournaments where id = target_tournament_id;
    perform public.propagate_tournament_winner(
      current_match_id,
      (select coalesce(player_one_id, player_two_id) from public.tournament_matches where id = current_match_id)
    );
  end loop;
end;
$$;

create or replace function public.report_tournament_match_winner(target_match_id uuid, target_winner_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  match_row public.tournament_matches;
  tournament_row public.tournaments;
begin
  select * into match_row from public.tournament_matches where id = target_match_id for update;
  if match_row.id is null then raise exception 'Partido no encontrado'; end if;
  select * into tournament_row from public.tournaments where id = match_row.tournament_id;
  if tournament_row.creator_id <> auth.uid()
    and not exists (select 1 from public.profiles where id = auth.uid() and role = 'Admin') then
    raise exception 'Solo el organizador puede reportar resultados';
  end if;
  if match_row.status = 'completed' then raise exception 'Este partido ya fue resuelto'; end if;
  if target_winner_id <> match_row.player_one_id and target_winner_id <> match_row.player_two_id then
    raise exception 'El ganador debe pertenecer al partido';
  end if;
  perform public.propagate_tournament_winner(target_match_id, target_winner_id);
end;
$$;

grant execute on function public.initialize_tournament_bracket(uuid) to authenticated;
grant execute on function public.report_tournament_match_winner(uuid, uuid) to authenticated;

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tournament_matches') then
    execute 'alter publication supabase_realtime add table public.tournament_matches';
  end if;
end $$;
