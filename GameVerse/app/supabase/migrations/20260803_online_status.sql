-- Estado online de usuarios
alter table public.profiles
  add column if not exists is_online boolean not null default false,
  add column if not exists last_seen_at timestamptz;

-- Función para marcar offline automáticamente si last_seen > 3 minutos
-- (útil para limpiar estados si el cliente se cierra sin avisarlos)
create or replace function public.mark_stale_users_offline()
returns void language sql security definer as $$
  update public.profiles
  set is_online = false
  where is_online = true
    and last_seen_at < now() - interval '3 minutes';
$$;
