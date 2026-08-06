-- Stores the vertical focal point selected in the banner preview.
-- -1 is top, 0 is center and 1 is bottom.
alter table public.profiles
  add column if not exists banner_position double precision not null default 0
  check (banner_position between -1 and 1);
