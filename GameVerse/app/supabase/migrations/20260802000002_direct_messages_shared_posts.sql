-- Referencia opcional para representar una publicación real dentro del chat.
alter table public.direct_messages
  add column if not exists shared_post_id uuid
  references public.posts(id) on delete set null;

create index if not exists direct_messages_shared_post_id_idx
  on public.direct_messages(shared_post_id)
  where shared_post_id is not null;
