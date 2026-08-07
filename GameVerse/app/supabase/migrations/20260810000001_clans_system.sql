-- Migración para el sistema de Clanes AAA en GameVerse

-- 1. Crear Tabla de Clanes
create table if not exists public.clans (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 3 and 50),
  tag text not null check (char_length(trim(tag)) between 2 and 6),
  description text not null default '' check (char_length(description) <= 500),
  logo_url text,
  banner_url text,
  region text not null default 'Global',
  language text not null default 'Español',
  visibility text not null default 'public' check (visibility in ('public', 'private', 'invite_only')),
  clan_type text not null default 'casual' check (clan_type in ('casual', 'competitive')),
  max_members integer not null default 50 check (max_members >= 1),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  verified boolean not null default false,
  level integer not null default 1 check (level >= 1),
  experience integer not null default 0 check (experience >= 0),
  accent_color text not null default '#6438FF',
  main_game_id text,
  -- Estadísticas desnormalizadas para rendimiento y escalabilidad
  tournaments_created integer not null default 0,
  tournaments_won integer not null default 0,
  events_hosted integer not null default 0,
  members_count integer not null default 1,
  posts_count integer not null default 0,
  unique (name),
  unique (tag)
);

-- 2. Crear Tabla de Roles Dinámicos de Clan
create table if not exists public.clan_roles (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 30),
  level integer not null default 10 check (level >= 0 and level <= 100), -- Nivel jerárquico (ej: 100=Líder, 10=Member)
  unique (clan_id, name)
);

-- 3. Crear Tabla de Permisos por Rol
create table if not exists public.clan_permissions (
  role_id uuid primary key references public.clan_roles(id) on delete cascade,
  can_manage_members boolean not null default false,
  can_kick boolean not null default false,
  can_create_tournaments boolean not null default false,
  can_manage_tournaments boolean not null default false,
  can_create_events boolean not null default false,
  can_manage_events boolean not null default false,
  can_manage_voice boolean not null default false,
  can_post_announcements boolean not null default false,
  can_edit_clan boolean not null default false
);

-- 4. Crear Tabla de Miembros del Clan
create table if not exists public.clan_members (
  clan_id uuid not null references public.clans(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid references public.clan_roles(id) on delete set null,
  joined_at timestamptz not null default now(),
  primary key (clan_id, user_id)
);

-- 5. Crear Tabla de Historial del Clan (Actividad Cronológica)
create table if not exists public.clan_history (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  action_type text not null, -- 'joined', 'left', 'kicked', 'role_changed', 'post_created', 'event_created', 'tournament_created', 'level_up'
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- 6. Crear Tabla de Invitaciones del Clan
create table if not exists public.clan_invites (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  invitee_id uuid not null references public.profiles(id) on delete cascade,
  inviter_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'cancelled'))
);

-- 7. Crear Tabla de Solicitudes de Ingreso
create table if not exists public.clan_requests (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  message text not null default '' check (char_length(message) <= 200),
  created_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected'))
);

-- 8. Crear Tabla de Eventos del Clan
create table if not exists public.clan_events (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 3 and 100),
  description text not null default '' check (char_length(description) <= 1000),
  event_date timestamptz not null,
  type text not null check (type in ('Torneo', 'Entrenamiento', 'Reunión', 'Evento', 'Stream')),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- 9. Actualizar tablas existentes
alter table public.posts
  add column if not exists clan_id uuid references public.clans(id) on delete cascade,
  add column if not exists clan_only boolean not null default false;

alter table public.tournaments
  add column if not exists clan_id uuid references public.clans(id) on delete set null;

alter table public.voice_channels
  add column if not exists clan_id uuid references public.clans(id) on delete cascade;

-- 10. Crear Índices de Rendimiento
create index if not exists clans_name_idx on public.clans (name);
create index if not exists clans_tag_idx on public.clans (tag);
create index if not exists clan_members_user_idx on public.clan_members (user_id);
create index if not exists clan_roles_clan_idx on public.clan_roles (clan_id);
create index if not exists clan_history_clan_idx on public.clan_history (clan_id, created_at desc);
create index if not exists clan_invites_invitee_idx on public.clan_invites (invitee_id, status);
create index if not exists clan_requests_clan_idx on public.clan_requests (clan_id, status);
create unique index if not exists clan_invites_active_idx on public.clan_invites (clan_id, invitee_id) where (status = 'pending');
create unique index if not exists clan_requests_active_idx on public.clan_requests (clan_id, user_id) where (status = 'pending');
create index if not exists clan_events_clan_idx on public.clan_events (clan_id, event_date);
create index if not exists posts_clan_idx on public.posts (clan_id);
create index if not exists tournaments_clan_idx on public.tournaments (clan_id);
create index if not exists voice_channels_clan_idx on public.voice_channels (clan_id);

-- 11. Habilitar RLS en nuevas tablas
alter table public.clans enable row level security;
alter table public.clan_roles enable row level security;
alter table public.clan_permissions enable row level security;
alter table public.clan_members enable row level security;
alter table public.clan_history enable row level security;
alter table public.clan_invites enable row level security;
alter table public.clan_requests enable row level security;
alter table public.clan_events enable row level security;

-- 12. Función Helper de Permisos del Clan
create or replace function public.has_clan_permission(p_user_id uuid, p_clan_id uuid, p_permission text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_is_owner boolean;
  v_role_id uuid;
  v_has_perm boolean;
begin
  -- Si el usuario es el dueño directo del clan, tiene todos los permisos
  select (owner_id = p_user_id) into v_is_owner from public.clans where id = p_clan_id;
  if coalesce(v_is_owner, false) then
    return true;
  end if;

  -- Buscar el rol del miembro
  select role_id into v_role_id from public.clan_members where clan_id = p_clan_id and user_id = p_user_id;
  if v_role_id is null then
    return false;
  end if;

  -- Consultar el permiso dinámicamente en la tabla de permisos
  execute format('select %I from public.clan_permissions where role_id = $1', p_permission)
  into v_has_perm
  using v_role_id;

  return coalesce(v_has_perm, false);
end;
$$;

-- 13. Políticas RLS
-- CLANS
create policy "Cualquiera autenticado puede ver clanes" on public.clans for select to authenticated using (true);
create policy "Cualquiera autenticado puede crear un clan" on public.clans for insert to authenticated with check (owner_id = auth.uid());
create policy "El líder o admin puede actualizar el clan" on public.clans for update to authenticated
  using (owner_id = auth.uid() or public.has_clan_permission(auth.uid(), id, 'can_edit_clan'));
create policy "Solo el líder puede borrar el clan" on public.clans for delete to authenticated using (owner_id = auth.uid());

-- CLAN ROLES
create policy "Cualquiera autenticado puede ver roles" on public.clan_roles for select to authenticated using (true);
create policy "Líderes o autorizados modifican roles" on public.clan_roles for all to authenticated
  using (public.has_clan_permission(auth.uid(), clan_id, 'can_edit_clan'));

-- CLAN PERMISSIONS
create policy "Cualquiera autenticado puede ver permisos" on public.clan_permissions for select to authenticated using (true);
create policy "Líderes o autorizados modifican permisos" on public.clan_permissions for all to authenticated
  using (exists (select 1 from public.clan_roles r where r.id = role_id and public.has_clan_permission(auth.uid(), r.clan_id, 'can_edit_clan')));

-- CLAN MEMBERS
create policy "Cualquiera autenticado puede ver miembros de clanes" on public.clan_members for select to authenticated using (true);
create policy "Un usuario se une al clan si es público o tiene invitación" on public.clan_members for insert to authenticated
  with check (
    -- El dueño del clan siempre puede insertarse a sí mismo
    exists (select 1 from public.clans c where c.id = clan_id and c.owner_id = auth.uid()) or
    -- O el usuario mismo se está insertando y el clan es público
    (user_id = auth.uid() and exists (select 1 from public.clans c where c.id = clan_id and c.visibility = 'public')) or
    -- O el usuario tiene una invitación pendiente aceptada
    (user_id = auth.uid() and exists (select 1 from public.clan_invites i where i.clan_id = clan_id and i.invitee_id = auth.uid() and i.status = 'accepted')) or
    -- O un moderador/líder inserta al usuario (vía solicitud aceptada)
    public.has_clan_permission(auth.uid(), clan_id, 'can_manage_members')
  );
create policy "Miembros pueden salir o ser expulsados por autorizados" on public.clan_members for delete to authenticated
  using (user_id = auth.uid() or public.has_clan_permission(auth.uid(), clan_id, 'can_kick'));
create policy "Admins pueden actualizar roles de miembros" on public.clan_members for update to authenticated
  using (public.has_clan_permission(auth.uid(), clan_id, 'can_manage_members'));

-- CLAN HISTORY
create policy "Cualquiera autenticado ve el historial de clanes" on public.clan_history for select to authenticated using (true);
create policy "Cualquiera autenticado puede insertar en historial" on public.clan_history for insert to authenticated with check (user_id = auth.uid());

-- CLAN INVITES
create policy "Usuarios ven sus invitaciones o admins ven las del clan" on public.clan_invites for select to authenticated
  using (invitee_id = auth.uid() or public.has_clan_permission(auth.uid(), clan_id, 'can_manage_members'));
create policy "Admins pueden crear invitaciones" on public.clan_invites for insert to authenticated
  with check (public.has_clan_permission(auth.uid(), clan_id, 'can_manage_members') and inviter_id = auth.uid());
create policy "El destinatario puede aceptar/rechazar e invitadores cancelar" on public.clan_invites for update to authenticated
  using (invitee_id = auth.uid() or public.has_clan_permission(auth.uid(), clan_id, 'can_manage_members'));

-- CLAN REQUESTS
create policy "Usuarios ven sus solicitudes o admins las del clan" on public.clan_requests for select to authenticated
  using (user_id = auth.uid() or public.has_clan_permission(auth.uid(), clan_id, 'can_manage_members'));
create policy "Cualquiera autenticado puede solicitar ingreso" on public.clan_requests for insert to authenticated
  with check (user_id = auth.uid());
create policy "Admins pueden aceptar/rechazar solicitudes" on public.clan_requests for update to authenticated
  using (public.has_clan_permission(auth.uid(), clan_id, 'can_manage_members'));

-- CLAN EVENTS
create policy "Cualquiera autenticado puede ver eventos de clan" on public.clan_events for select to authenticated using (true);
create policy "Admins del clan pueden crear eventos" on public.clan_events for insert to authenticated
  with check (public.has_clan_permission(auth.uid(), clan_id, 'can_create_events') and creator_id = auth.uid());
create policy "Admins del clan pueden editar eventos" on public.clan_events for update to authenticated
  using (public.has_clan_permission(auth.uid(), clan_id, 'can_manage_events'));
create policy "Admins pueden borrar eventos" on public.clan_events for delete to authenticated
  using (public.has_clan_permission(auth.uid(), clan_id, 'can_manage_events') or creator_id = auth.uid());


-- 14. Trigger de Automatización para Nuevos Clanes
create or replace function public.setup_default_clan_roles()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_leader_role_id uuid;
  v_coleader_role_id uuid;
  v_moderator_role_id uuid;
  v_member_role_id uuid;
begin
  -- Crear Roles por Defecto
  insert into public.clan_roles (clan_id, name, level) values
    (new.id, 'Leader', 100) returning id into v_leader_role_id;
  insert into public.clan_roles (clan_id, name, level) values
    (new.id, 'Co-Leader', 75) returning id into v_coleader_role_id;
  insert into public.clan_roles (clan_id, name, level) values
    (new.id, 'Moderator', 50) returning id into v_moderator_role_id;
  insert into public.clan_roles (clan_id, name, level) values
    (new.id, 'Member', 10) returning id into v_member_role_id;

  -- Crear Permisos para cada Rol
  -- Leader: Todos los permisos habilitados
  insert into public.clan_permissions (role_id, can_manage_members, can_kick, can_create_tournaments, can_manage_tournaments, can_create_events, can_manage_events, can_manage_voice, can_post_announcements, can_edit_clan)
  values (v_leader_role_id, true, true, true, true, true, true, true, true, true);

  -- Co-Leader: Todos los permisos habilitados
  insert into public.clan_permissions (role_id, can_manage_members, can_kick, can_create_tournaments, can_manage_tournaments, can_create_events, can_manage_events, can_manage_voice, can_post_announcements, can_edit_clan)
  values (v_coleader_role_id, true, true, true, true, true, true, true, true, true);

  -- Moderator: Moderación, eventos, canales de voz y publicaciones de anuncios
  insert into public.clan_permissions (role_id, can_manage_members, can_kick, can_create_tournaments, can_manage_tournaments, can_create_events, can_manage_events, can_manage_voice, can_post_announcements, can_edit_clan)
  values (v_moderator_role_id, true, true, false, false, true, true, true, true, false);

  -- Member: Ningún permiso administrativo
  insert into public.clan_permissions (role_id, can_manage_members, can_kick, can_create_tournaments, can_manage_tournaments, can_create_events, can_manage_events, can_manage_voice, can_post_announcements, can_edit_clan)
  values (v_member_role_id, false, false, false, false, false, false, false, false, false);

  -- Añadir al Creador como Líder en la tabla de miembros
  insert into public.clan_members (clan_id, user_id, role_id)
  values (new.id, new.owner_id, v_leader_role_id);

  -- Registrar acción de creación en el Historial
  insert into public.clan_history (clan_id, user_id, action_type, metadata)
  values (new.id, new.owner_id, 'clan_created', jsonb_build_object('clan_name', new.name, 'tag', new.tag));

  return new;
end;
$$;

create or replace trigger setup_default_clan_roles_trigger
after insert on public.clans
for each row execute function public.setup_default_clan_roles();


-- 15. Triggers para Mantener Estadísticas Desnormalizadas Sincronizadas
-- Miembros del clan
create or replace function public.sync_clan_members_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    update public.clans set members_count = members_count + 1 where id = new.clan_id;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.clans set members_count = greatest(1, members_count - 1) where id = old.clan_id;
    return old;
  end if;
  return null;
end;
$$;

create or replace trigger sync_clan_members_count_trigger
after insert or delete on public.clan_members
for each row execute function public.sync_clan_members_count();

-- Publicaciones del clan
create or replace function public.sync_clan_posts_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    if new.clan_id is not null then
      update public.clans set posts_count = posts_count + 1 where id = new.clan_id;
    end if;
    return new;
  elsif (tg_op = 'DELETE') then
    if old.clan_id is not null then
      update public.clans set posts_count = greatest(0, posts_count - 1) where id = old.clan_id;
    end if;
    return old;
  end if;
  return null;
end;
$$;

create or replace trigger sync_clan_posts_count_trigger
after insert or delete on public.posts
for each row execute function public.sync_clan_posts_count();

-- Torneos del clan
create or replace function public.sync_clan_tournaments_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    if new.clan_id is not null then
      update public.clans set tournaments_created = tournaments_created + 1 where id = new.clan_id;
    end if;
    return new;
  elsif (tg_op = 'DELETE') then
    if old.clan_id is not null then
      update public.clans set tournaments_created = greatest(0, tournaments_created - 1) where id = old.clan_id;
    end if;
    return old;
  end if;
  return null;
end;
$$;

create or replace trigger sync_clan_tournaments_count_trigger
after insert or delete on public.tournaments
for each row execute function public.sync_clan_tournaments_count();

-- Eventos del clan
create or replace function public.sync_clan_events_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    update public.clans set events_hosted = events_hosted + 1 where id = new.clan_id;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.clans set events_hosted = greatest(0, events_hosted - 1) where id = old.clan_id;
    return old;
  end if;
  return null;
end;
$$;

create or replace trigger sync_clan_events_count_trigger
after insert or delete on public.clan_events
for each row execute function public.sync_clan_events_count();


-- 16. Habilitar Realtime para las tablas de clanes
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clans') then
    execute 'alter publication supabase_realtime add table public.clans';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_roles') then
    execute 'alter publication supabase_realtime add table public.clan_roles';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_permissions') then
    execute 'alter publication supabase_realtime add table public.clan_permissions';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_members') then
    execute 'alter publication supabase_realtime add table public.clan_members';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_history') then
    execute 'alter publication supabase_realtime add table public.clan_history';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_invites') then
    execute 'alter publication supabase_realtime add table public.clan_invites';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_requests') then
    execute 'alter publication supabase_realtime add table public.clan_requests';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'clan_events') then
    execute 'alter publication supabase_realtime add table public.clan_events';
  end if;
end $$;

-- 17. Configurar Bucket de Almacenamiento de Clanes
insert into storage.buckets (id, name, public)
values ('clans', 'clans', true)
on conflict (id) do nothing;
