-- Chat en tiempo real para directos
create table if not exists public.live_stream_messages (
  id          uuid primary key default gen_random_uuid(),
  stream_id   uuid not null references public.live_streams(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  username    text not null default '',
  avatar_url  text,
  message     text not null,
  created_at  timestamptz not null default now()
);

alter table public.live_stream_messages enable row level security;

create policy "Cualquiera puede leer mensajes de directos"
  on public.live_stream_messages for select using (true);

create policy "Usuarios autenticados pueden enviar mensajes"
  on public.live_stream_messages for insert with check (auth.uid() = user_id);

alter publication supabase_realtime add table public.live_stream_messages;
