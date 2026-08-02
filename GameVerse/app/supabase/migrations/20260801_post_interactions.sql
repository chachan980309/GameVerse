-- Comentarios vinculados al perfil que los escribió.
alter table public.comments
  add column if not exists user_id uuid references public.profiles(id) on delete cascade;

-- Recupera la relación de los comentarios antiguos cuando el nombre coincide.
update public.comments as c
set user_id = p.id
from public.profiles as p
where c.user_id is null
  and lower(trim(c.username)) = lower(trim(p.username));

create index if not exists comments_post_id_created_at_idx
  on public.comments(post_id, created_at);

-- Un usuario solo puede dar un like por publicación.
alter table public.post_likes
  add column if not exists user_id uuid references public.profiles(id) on delete cascade;

delete from public.post_likes as old_like
using public.post_likes as new_like
where old_like.ctid < new_like.ctid
  and old_like.post_id = new_like.post_id
  and old_like.user_id = new_like.user_id;

create unique index if not exists post_likes_post_id_user_id_key
  on public.post_likes(post_id, user_id);

alter table public.comments enable row level security;
alter table public.post_likes enable row level security;

drop policy if exists "Anyone can read comments" on public.comments;
drop policy if exists "Users can create their own comments" on public.comments;
create policy "Anyone can read comments"
  on public.comments for select to authenticated using (true);
create policy "Users can create their own comments"
  on public.comments for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Anyone can read post likes" on public.post_likes;
drop policy if exists "Users can add their own likes" on public.post_likes;
drop policy if exists "Users can remove their own likes" on public.post_likes;
create policy "Anyone can read post likes"
  on public.post_likes for select to authenticated using (true);
create policy "Users can add their own likes"
  on public.post_likes for insert to authenticated
  with check (auth.uid() = user_id);
create policy "Users can remove their own likes"
  on public.post_likes for delete to authenticated
  using (auth.uid() = user_id);
