-- Return the dashboard's trend card as four aggregate rows instead of
-- transferring every user_games row to every connected client.
-- SECURITY INVOKER keeps the function subject to the caller's RLS policies.
create or replace function public.get_game_trends(result_limit integer default 4)
returns table (game_name text, player_count bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select
    ug.game_name,
    count(*) as player_count
  from public.user_games as ug
  where nullif(trim(ug.game_name), '') is not null
  group by ug.game_name
  order by player_count desc, ug.game_name asc
  limit greatest(1, least(coalesce(result_limit, 4), 20));
$$;
