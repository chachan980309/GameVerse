-- Encuestas asociadas a publicaciones. Las opciones viven en el post y cada
-- usuario autenticado puede emitir o cambiar un único voto por encuesta.
alter table public.posts
  add column if not exists poll_question text,
  add column if not exists poll_options jsonb;

create table if not exists public.poll_votes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  option_index integer not null check (option_index >= 0 and option_index < 6),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.poll_votes enable row level security;

drop policy if exists "Authenticated users can read poll votes" on public.poll_votes;
create policy "Authenticated users can read poll votes"
  on public.poll_votes for select to authenticated using (true);

drop policy if exists "Users can create their own poll vote" on public.poll_votes;
create policy "Users can create their own poll vote"
  on public.poll_votes for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own poll vote" on public.poll_votes;
create policy "Users can update their own poll vote"
  on public.poll_votes for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists poll_votes_post_id_idx on public.poll_votes(post_id);
