-- Stores the zoom level selected in the banner preview.
alter table public.profiles
  add column if not exists banner_scale double precision not null default 1
  check (banner_scale between 1 and 2.4);
