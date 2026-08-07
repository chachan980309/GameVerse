-- Hardening de Seguridad para el Sistema de Clanes en GameVerse

-- 1. Función Helper para verificar si un usuario es administrador/dueño de un clan
create or replace function public.is_clan_admin(p_user_id uuid, p_clan_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  return exists (
    -- El usuario es el dueño directo del clan
    select 1 from public.clans c where c.id = p_clan_id and c.owner_id = p_user_id
  ) or exists (
    -- O el usuario es un miembro del clan con rol administrativo (can_edit_clan = true)
    select 1 from public.clan_members m
    join public.clan_roles r on r.id = m.role_id
    join public.clan_permissions p on p.role_id = r.id
    where m.clan_id = p_clan_id and m.user_id = p_user_id
    and p.can_edit_clan = true
  );
end;
$$;

-- 2. Restricciones de seguridad para el almacenamiento (Storage) del bucket 'clans'
-- Solo los líderes o administradores autorizados de un clan pueden subir logos o banners a su carpeta respectiva
drop policy if exists "Clans auth insert" on storage.objects;
create policy "Clans auth insert"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'clans' and
  public.is_clan_admin(auth.uid(), (storage.foldername(name))[1]::uuid)
);

drop policy if exists "Clans auth delete" on storage.objects;
create policy "Clans auth delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'clans' and
  public.is_clan_admin(auth.uid(), (storage.foldername(name))[1]::uuid)
);


-- 3. Trigger para Prevenir Manipulaciones Directas de Estadísticas y Niveles desde el Cliente
create or replace function public.prevent_clan_stats_tampering()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Prevenir que usuarios comunes alteren directamente el nivel, experiencia, victorias o conteo de miembros
  if (
    new.level <> old.level or 
    new.experience <> old.experience or 
    new.verified <> old.verified or 
    new.members_count <> old.members_count or 
    new.posts_count <> old.posts_count or 
    new.tournaments_created <> old.tournaments_created or 
    new.tournaments_won <> old.tournaments_won or 
    new.events_hosted <> old.events_hosted
  ) then
    -- Restauramos de forma segura los valores reales de base de datos para abortar manipulaciones del cliente
    new.level := old.level;
    new.experience := old.experience;
    new.verified := old.verified;
    new.members_count := old.members_count;
    new.posts_count := old.posts_count;
    new.tournaments_created := old.tournaments_created;
    new.tournaments_won := old.tournaments_won;
    new.events_hosted := old.events_hosted;
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_clan_stats_tampering_trigger on public.clans;
create trigger prevent_clan_stats_tampering_trigger
before update on public.clans
for each row execute function public.prevent_clan_stats_tampering();
