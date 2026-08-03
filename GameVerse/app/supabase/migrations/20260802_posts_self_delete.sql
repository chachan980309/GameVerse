-- Permite borrar una publicación solamente al usuario que la creó.
-- Ejecutar esta migración en Supabase antes de probar el botón en producción.

grant delete on table public.posts to authenticated;

alter table public.posts enable row level security;

drop policy if exists "Users can delete their own posts" on public.posts;

create policy "Users can delete their own posts"
on public.posts
for delete
to authenticated
using ((select auth.uid()) = user_id);
