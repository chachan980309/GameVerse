-- Ejecutar una sola vez para que likes y comentarios se actualicen en vivo.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_likes'
  ) then
    execute 'alter publication supabase_realtime add table public.post_likes';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'comments'
  ) then
    execute 'alter publication supabase_realtime add table public.comments';
  end if;
end;
$$;
