create table if not exists public.voice_channels (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 60),
  room_name text not null unique check (room_name ~ '^[a-zA-Z0-9_-]+$'),
  description text not null default '' check (char_length(description) <= 120),
  created_by uuid not null references auth.users(id) on delete cascade,
  is_featured boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists voice_channels_active_created_idx
  on public.voice_channels (is_active, created_at desc);
create index if not exists voice_channels_created_by_idx
  on public.voice_channels (created_by, created_at desc);

create table if not exists public.voice_channel_members (
  channel_id uuid not null references public.voice_channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create index if not exists voice_channel_members_user_idx
  on public.voice_channel_members (user_id, joined_at desc);

alter table public.voice_channels enable row level security;
alter table public.voice_channel_members enable row level security;

drop policy if exists "Authenticated users read active voice channels" on public.voice_channels;
create policy "Authenticated users read active voice channels"
on public.voice_channels for select to authenticated
using (is_active or created_by = auth.uid());

drop policy if exists "Users create their own voice channels" on public.voice_channels;
create policy "Users create their own voice channels"
on public.voice_channels for insert to authenticated
with check (created_by = auth.uid());

drop policy if exists "Owners update voice channels" on public.voice_channels;

drop policy if exists "Owners delete voice channels" on public.voice_channels;
create policy "Owners delete voice channels"
on public.voice_channels for delete to authenticated
using (created_by = auth.uid());

drop policy if exists "Users read voice memberships" on public.voice_channel_members;
create policy "Users read voice memberships"
on public.voice_channel_members for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Users join voice channels" on public.voice_channel_members;
create policy "Users join voice channels"
on public.voice_channel_members for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users leave voice channels" on public.voice_channel_members;
create policy "Users leave voice channels"
on public.voice_channel_members for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "Users refresh their voice memberships" on public.voice_channel_members;
create policy "Users refresh their voice memberships"
on public.voice_channel_members for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
