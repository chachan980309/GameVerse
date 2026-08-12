-- Medio editable desde Supabase para el hero de Clanes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'site-media',
  'site-media',
  true,
  26214400,
  array['video/mp4', 'video/quicktime']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public site media is readable" on storage.objects;
create policy "Public site media is readable"
on storage.objects for select
using (bucket_id = 'site-media');

create table if not exists public.app_media_config (
  key text primary key check (char_length(trim(key)) between 1 and 80),
  storage_bucket text not null,
  storage_path text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_media_config enable row level security;

drop policy if exists "Authenticated users can read media config" on public.app_media_config;
create policy "Authenticated users can read media config"
on public.app_media_config for select to authenticated using (true);

insert into public.app_media_config (key, storage_bucket, storage_path)
values ('clans_hero_background', 'site-media', 'clans/nubzzz-competitive-heart.mov')
on conflict (key) do update
set storage_bucket = excluded.storage_bucket,
    storage_path = excluded.storage_path,
    updated_at = now();
