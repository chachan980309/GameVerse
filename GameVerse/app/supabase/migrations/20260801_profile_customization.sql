-- Run this migration in the Supabase SQL editor before using the new profile editor.
-- Existing profiles keep working; all new fields are optional.
alter table public.profiles
  add column if not exists handle text,
  add column if not exists motto text,
  add column if not exists location text,
  add column if not exists platform text,
  add column if not exists role text,
  add column if not exists favorite_game text,
  add column if not exists joined_at date default current_date;

-- A handle must be unique only when the user decides to set one.
create unique index if not exists profiles_handle_unique
  on public.profiles (lower(handle))
  where handle is not null and handle <> '';
