-- Ejecutar una sola vez para actualizar en vivo el panel derecho del perfil.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles') then
    execute 'alter publication supabase_realtime add table public.profiles';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'posts') then
    execute 'alter publication supabase_realtime add table public.posts';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'user_games') then
    execute 'alter publication supabase_realtime add table public.user_games';
  end if;
end;
$$;
