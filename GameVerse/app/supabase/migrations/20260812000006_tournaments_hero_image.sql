insert into public.app_media_config (key, storage_bucket, storage_path)
values ('tournaments_hero_background', 'site-media', 'tournaments/nubzzz-tournaments-hero.png')
on conflict (key) do update
set storage_bucket = excluded.storage_bucket,
    storage_path = excluded.storage_path,
    updated_at = now();
