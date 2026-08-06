-- Create Tournaments Table
create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 3 and 100),
  description text not null,
  game_name text not null,
  game_image_url text,
  cover_url text,
  banner_url text,
  rules text,
  prizes text,
  max_players integer not null default 16 check (max_players >= 2),
  start_date timestamptz not null,
  type text not null check (type in ('single_elimination', 'double_elimination', 'round_robin')),
  status text not null default 'registration' check (status in ('draft', 'registration', 'in_progress', 'finished', 'cancelled')),
  privacy text not null default 'public' check (privacy in ('public', 'private')),
  password text,
  region text not null,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  is_official boolean not null default false,
  created_at timestamptz not null default now()
);

-- Create Tournament Participants Table
create table if not exists public.tournament_participants (
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (tournament_id, user_id)
);

-- Create Indexes for performance
create index if not exists tournaments_game_idx on public.tournaments (game_name);
create index if not exists tournaments_creator_idx on public.tournaments (creator_id);
create index if not exists tournaments_status_idx on public.tournaments (status);
create index if not exists tournament_participants_user_idx on public.tournament_participants (user_id);

-- Enable RLS on both tables
alter table public.tournaments enable row level security;
alter table public.tournament_participants enable row level security;

-- Tournaments Table RLS Policies
drop policy if exists "Authenticated users can read tournaments" on public.tournaments;
create policy "Authenticated users can read tournaments"
on public.tournaments for select to authenticated
using (true);

drop policy if exists "Authenticated users can insert tournaments" on public.tournaments;
create policy "Authenticated users can insert tournaments"
on public.tournaments for insert to authenticated
with check (creator_id = auth.uid());

drop policy if exists "Creators can update their tournaments" on public.tournaments;
create policy "Creators can update their tournaments"
on public.tournaments for update to authenticated
using (creator_id = auth.uid() or exists (
  select 1 from public.profiles where id = auth.uid() and role = 'Admin'
))
with check (creator_id = auth.uid() or exists (
  select 1 from public.profiles where id = auth.uid() and role = 'Admin'
));

drop policy if exists "Creators can delete their tournaments" on public.tournaments;
create policy "Creators can delete their tournaments"
on public.tournaments for delete to authenticated
using (creator_id = auth.uid() or exists (
  select 1 from public.profiles where id = auth.uid() and role = 'Admin'
));

-- Tournament Participants Table RLS Policies
drop policy if exists "Authenticated users can read tournament participants" on public.tournament_participants;
create policy "Authenticated users can read tournament participants"
on public.tournament_participants for select to authenticated
using (true);

drop policy if exists "Users can join tournaments" on public.tournament_participants;
create policy "Users can join tournaments"
on public.tournament_participants for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can leave tournaments" on public.tournament_participants;
create policy "Users can leave tournaments"
on public.tournament_participants for delete to authenticated
using (user_id = auth.uid());

-- Enable Realtime for Tournaments and Participants
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tournaments') then
    execute 'alter publication supabase_realtime add table public.tournaments';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tournament_participants') then
    execute 'alter publication supabase_realtime add table public.tournament_participants';
  end if;
end $$;

-- Set up storage bucket for tournaments
insert into storage.buckets (id, name, public)
values ('tournaments', 'tournaments', true)
on conflict (id) do nothing;

-- Set up Storage Policies for tournaments bucket
drop policy if exists "Tournaments public read" on storage.objects;
create policy "Tournaments public read"
on storage.objects for select to public
using (bucket_id = 'tournaments');

drop policy if exists "Tournaments auth insert" on storage.objects;
create policy "Tournaments auth insert"
on storage.objects for insert to authenticated
with check (bucket_id = 'tournaments');

drop policy if exists "Tournaments auth delete" on storage.objects;
create policy "Tournaments auth delete"
on storage.objects for delete to authenticated
using (bucket_id = 'tournaments');
