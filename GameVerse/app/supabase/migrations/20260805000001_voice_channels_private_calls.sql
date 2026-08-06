-- Add private call columns to voice_channels table
alter table public.voice_channels 
  add column if not exists is_private boolean not null default false,
  add column if not exists invitee_id uuid references auth.users(id) on delete cascade,
  add column if not exists private_status text check (private_status in ('ringing', 'accepted', 'rejected', 'ended'));

-- Create index for faster querying of private calls
create index if not exists voice_channels_private_idx 
  on public.voice_channels (is_private, invitee_id, private_status);

-- Update RLS policies on public.voice_channels
drop policy if exists "Authenticated users read active voice channels" on public.voice_channels;
create policy "Authenticated users read active voice channels"
on public.voice_channels for select to authenticated
using (
  is_active = true and (
    is_private = false 
    or created_by = auth.uid() 
    or invitee_id = auth.uid()
  )
);

-- Update RLS policies on public.voice_channel_members
drop policy if exists "Users read voice memberships" on public.voice_channel_members;
create policy "Users read voice memberships"
on public.voice_channel_members for select to authenticated
using (
  exists (
    select 1 from public.voice_channels
    where id = channel_id
    and (
      is_private = false 
      or created_by = auth.uid() 
      or invitee_id = auth.uid()
    )
  )
);

drop policy if exists "Users join voice channels" on public.voice_channel_members;
create policy "Users join voice channels"
on public.voice_channel_members for insert to authenticated
with check (
  user_id = auth.uid() 
  and exists (
    select 1 from public.voice_channels
    where id = channel_id
    and (
      is_private = false 
      or created_by = auth.uid() 
      or invitee_id = auth.uid()
    )
  )
);

-- Ensure table and membership changes are propagated through Realtime
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'voice_channels') then
    execute 'alter publication supabase_realtime add table public.voice_channels';
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'voice_channel_members') then
    execute 'alter publication supabase_realtime add table public.voice_channel_members';
  end if;
end $$;

-- Trigger to automatically clean up private voice channels when they become empty
create or replace function public.cleanup_empty_private_channels()
returns trigger as $$
declare
  is_priv boolean;
  member_count integer;
begin
  -- Check if the channel is private
  select is_private into is_priv from public.voice_channels where id = old.channel_id;
  
  if is_priv = true then
    -- Count remaining members
    select count(*) into member_count from public.voice_channel_members where channel_id = old.channel_id;
    if member_count = 0 then
      delete from public.voice_channels where id = old.channel_id;
    end if;
  end if;
  return old;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_cleanup_private_channels on public.voice_channel_members;
create trigger trigger_cleanup_private_channels
after delete on public.voice_channel_members
for each row execute function public.cleanup_empty_private_channels();

-- Trigger to clean up private channels when their status updates to 'rejected' or 'ended'
create or replace function public.cleanup_private_channels_by_status()
returns trigger as $$
begin
  if new.is_private = true and (new.private_status = 'rejected' or new.private_status = 'ended') then
    delete from public.voice_channels where id = new.id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_cleanup_channels_status on public.voice_channels;
create trigger trigger_cleanup_channels_status
after update of private_status on public.voice_channels
for each row execute function public.cleanup_private_channels_by_status();

-- Clean up old private_calls table if it exists
drop table if exists public.private_calls cascade;
