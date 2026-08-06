-- Permite a cada usuario autenticado actualizar exclusivamente su propio perfil.
-- Necesario para avatar, portada y el formulario de editar perfil.

grant select, update on table public.profiles to authenticated;

alter table public.profiles enable row level security;

drop policy if exists "Authenticated users update own profile" on public.profiles;

create policy "Authenticated users update own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
