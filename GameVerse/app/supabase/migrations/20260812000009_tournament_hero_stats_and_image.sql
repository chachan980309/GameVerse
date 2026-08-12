-- Métricas reales para las tarjetas del encabezado de Torneos.
create or replace function public.get_tournament_community_stats()
returns table (
  tournaments_count bigint,
  participants_count bigint,
  live_count bigint,
  upcoming_count bigint
)
language sql
stable
set search_path = public
as $$
  select
    (
      select count(*)
      from public.tournaments
      where status <> 'archived'
    ) as tournaments_count,
    (select count(*) from public.tournament_participants) as participants_count,
    (
      select count(*)
      from public.tournaments
      where status = 'in_progress'
    ) as live_count,
    (
      select count(*)
      from public.tournaments
      where status in ('registration', 'full')
        and start_date >= now()
    ) as upcoming_count;
$$;

grant execute on function public.get_tournament_community_stats() to authenticated;

-- Nuevo arte de hero, alojado en Supabase Storage.
update public.app_media_config
set
  storage_bucket = 'site-media',
  storage_path = 'tournaments/nubzzz-tournaments-hero-v3.png',
  updated_at = now()
where key = 'tournaments_hero_background';
