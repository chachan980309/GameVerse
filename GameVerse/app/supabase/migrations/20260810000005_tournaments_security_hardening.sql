-- Hardening de Seguridad para el Sistema de Torneos en GameVerse

-- 1. Redefinir la política INSERT de Torneos para evitar forzar 'is_official = true' desde el cliente
drop policy if exists "Authenticated users can insert tournaments" on public.tournaments;
create policy "Authenticated users can insert tournaments"
on public.tournaments for insert to authenticated
with check (
  creator_id = auth.uid() and
  (is_official = false or exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ))
);

-- 2. Trigger de Base de Datos para evitar escalar torneos a oficiales durante una actualización (UPDATE)
create or replace function public.prevent_tournament_official_tampering()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Si el estado is_official cambia a verdadero, verificar que el creador/actualizador sea un admin real
  if (new.is_official <> old.is_official and new.is_official = true) then
    if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
      -- Abortar la escala y restaurar el valor original
      new.is_official := old.is_official;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_tournament_official_tampering_trigger on public.tournaments;
create trigger prevent_tournament_official_tampering_trigger
before update on public.tournaments
for each row execute function public.prevent_tournament_official_tampering();
