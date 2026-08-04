-- Tabla de transmisiones en directo
create table if not exists public.live_streams (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  room_name   text not null,
  title       text not null default '',
  is_live     boolean not null default true,
  viewer_count int not null default 0,
  created_at  timestamptz not null default now(),
  ended_at    timestamptz
);

-- Columna stream_id en posts para enlazar un post con su directo
alter table public.posts
  add column if not exists stream_id uuid references public.live_streams(id) on delete set null;

-- RLS
alter table public.live_streams enable row level security;

create policy "Cualquiera puede ver directos activos"
  on public.live_streams for select
  using (true);

create policy "El usuario crea sus propios directos"
  on public.live_streams for insert
  with check (auth.uid() = user_id);

create policy "El usuario actualiza sus propios directos"
  on public.live_streams for update
  using (auth.uid() = user_id);

-- Realtime
alter publication supabase_realtime add table public.live_streams;
