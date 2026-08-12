-- Reemplaza el arte del hero de Torneos por la composición actualizada.
update public.app_media_config
set
  storage_bucket = 'site-media',
  storage_path = 'tournaments/nubzzz-tournaments-hero-v2.png',
  updated_at = now()
where key = 'tournaments_hero_background';
