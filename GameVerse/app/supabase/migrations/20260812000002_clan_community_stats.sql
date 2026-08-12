-- Totales reales para el encabezado de la comunidad de clanes.
create or replace function public.get_clan_community_stats()
returns table (
  clans_count bigint,
  members_count bigint,
  tournaments_count bigint,
  events_this_month_count bigint
)
language sql
stable
set search_path = public
as $$
  select
    (select count(*) from public.clans) as clans_count,
    (select count(*) from public.clan_members) as members_count,
    (select count(*) from public.tournaments where clan_id is not null)
      as tournaments_count,
    (
      select count(*)
      from public.clan_events
      where event_date >= date_trunc('month', now())
        and event_date < date_trunc('month', now()) + interval '1 month'
    ) as events_this_month_count;
$$;

grant execute on function public.get_clan_community_stats() to authenticated;
