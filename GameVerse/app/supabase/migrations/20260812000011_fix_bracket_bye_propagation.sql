-- Un bye solo se resuelve al crear la primera ronda. No debe seguir
-- avanzando por rondas todavía incompletas.
create or replace function public.propagate_tournament_winner(match_id uuid, player_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_match public.tournament_matches;
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
