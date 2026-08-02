create table if not exists public.post_shares (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists post_shares_post_id_idx
  on public.post_shares(post_id);

alter table public.post_shares enable row level security;

drop policy if exists "Authenticated users can read post shares" on public.post_shares;
create policy "Authenticated users can read post shares"
  on public.post_shares for select to authenticated using (true);

drop policy if exists "Users can create their own post shares" on public.post_shares;
create policy "Users can create their own post shares"
  on public.post_shares for insert to authenticated
  with check (auth.uid() = user_id);

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'post_shares'
  ) then
    execute 'alter publication supabase_realtime add table public.post_shares';
  end if;
end $$;
