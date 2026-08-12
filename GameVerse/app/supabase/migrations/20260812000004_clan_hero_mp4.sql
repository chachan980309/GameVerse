-- Reemplaza el medio del hero por la versión MP4 publicada desde Storage.
update public.app_media_config
set storage_bucket = 'site-media',
    storage_path = 'clans/nubzzz-competitive-heart.mp4',
    updated_at = now()
where key = 'clans_hero_background';
