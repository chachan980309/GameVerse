-- Reserva el hero de Amigos para una imagen gestionada desde Supabase.
insert into public.app_media_config (key, storage_bucket, storage_path)
values ('friends_hero_background', 'site-media', 'friends/friends-hero.png')
on conflict (key) do update
set storage_bucket = excluded.storage_bucket,
    storage_path = excluded.storage_path,
    updated_at = now();
