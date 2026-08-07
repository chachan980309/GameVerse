-- Tabla de Mensajes de Chat de Clanes

create table if not exists public.clan_messages (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 2000),
  created_at timestamptz not null default now()
);

-- Índices de Rendimiento
create index if not exists clan_messages_idx on public.clan_messages (clan_id, created_at desc);

-- Habilitar RLS
alter table public.clan_messages enable row level security;

-- Políticas de RLS
create policy "Miembros del clan pueden leer mensajes" on public.clan_messages
  for select to authenticated
  using (exists (select 1 from public.clan_members m where m.clan_id = clan_messages.clan_id and m.user_id = auth.uid()));

create policy "Miembros del clan pueden enviar mensajes" on public.clan_messages
  for insert to authenticated
  with check (
    sender_id = auth.uid() and
    exists (select 1 from public.clan_members m where m.clan_id = clan_messages.clan_id and m.user_id = auth.uid())
  );

-- Habilitar Realtime
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_messages') then
    execute 'alter publication supabase_realtime add table public.clan_messages';
  end if;
end $$;
