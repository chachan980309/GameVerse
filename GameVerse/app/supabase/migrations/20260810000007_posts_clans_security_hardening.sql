-- Hardening de RLS para Tabla de Publicaciones (Filtro de Clanes Privados)

-- 1. Redefinir políticas SELECT de public.posts para ocultar posts de clanes privados a no miembros
drop policy if exists "Anyone can read posts" on public.posts;
drop policy if exists "Users read authorized posts" on public.posts;

create policy "Users read authorized posts"
on public.posts for select to authenticated
using (
  -- Permite ver si la publicación no está asociada a ningún clan
  clan_id is null or 
  -- O si la publicación está asociada a un clan pero NO es marcada de lectura exclusiva de miembros (clan_only = false)
  clan_only = false or 
  -- O si el usuario autenticado es un miembro activo del clan asociado
  exists (
    select 1 from public.clan_members m 
    where m.clan_id = posts.clan_id and m.user_id = auth.uid()
  )
);
