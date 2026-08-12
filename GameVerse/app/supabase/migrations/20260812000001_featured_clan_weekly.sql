-- Clan destacado semanal basado únicamente en actividad registrada.
-- No almacena datos duplicados ni depende de valores de demostración.

create index if not exists clan_history_recent_activity_idx
  on public.clan_history (created_at desc, clan_id);

create index if not exists clan_events_recent_activity_idx
  on public.clan_events (created_at desc, clan_id);

create or replace function public.get_featured_clan_weekly()
returns setof public.clans
language sql
stable
set search_path = public
as $$
  select c.*
  from public.clans c
  left join lateral (
    select count(*)::integer as history_actions
    from public.clan_history h
    where h.clan_id = c.id
      and h.created_at >= now() - interval '7 days'
  ) history on true
  left join lateral (
    select count(*)::integer as upcoming_events
    from public.clan_events e
    where e.clan_id = c.id
      and e.event_date >= now()
      and e.event_date < now() + interval '7 days'
  ) events on true
  where c.visibility = 'public'
  order by
    -- La actividad reciente es el criterio principal para el destacado.
    (coalesce(history.history_actions, 0) * 100
      + coalesce(events.upcoming_events, 0) * 80
      + c.posts_count * 3
      + c.tournaments_created * 12
      + c.tournaments_won * 25
      + c.members_count) desc,
    c.verified desc,
    c.experience desc,
    c.created_at asc
  limit 1;
$$;

grant execute on function public.get_featured_clan_weekly() to authenticated;
