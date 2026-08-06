-- Notifications produced by real social interactions.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null check (type in ('like', 'comment', 'mention', 'share', 'friend_request', 'message')),
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.posts
  add column if not exists shared_post_id uuid references public.posts(id) on delete set null;

create index if not exists notifications_recipient_created_idx
  on public.notifications(recipient_id, created_at desc);

alter table public.notifications enable row level security;
drop policy if exists "Users can read their notifications" on public.notifications;
drop policy if exists "Users can update their notifications" on public.notifications;
drop policy if exists "Users can create share notifications" on public.notifications;
create policy "Users can read their notifications"
  on public.notifications for select to authenticated using (auth.uid() = recipient_id);
create policy "Users can update their notifications"
  on public.notifications for update to authenticated using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);
create policy "Users can create share notifications"
  on public.notifications for insert to authenticated
  with check (auth.uid() = actor_id and type = 'share');

create or replace function public.create_notification(
  target uuid, actor uuid, notice_type text, source_post uuid default null, source_comment uuid default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if target is null or actor is null or target = actor then return; end if;
  insert into public.notifications(recipient_id, actor_id, type, post_id, comment_id)
  values (target, actor, notice_type, source_post, source_comment);
end;
$$;

create or replace function public.notify_new_like() returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id = new.post_id;
  perform public.create_notification(owner_id, new.user_id, 'like', new.post_id);
  return new;
end;
$$;

create or replace function public.notify_new_comment() returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id = new.post_id;
  perform public.create_notification(owner_id, new.user_id, 'comment', new.post_id, new.id);
  return new;
end;
$$;

create or replace function public.notify_mentions() returns trigger language plpgsql security definer set search_path = public as $$
declare username_match text; mentioned_id uuid;
begin
  for username_match in select (regexp_matches(coalesce(new.content, ''), '@([A-Za-z0-9_.-]+)', 'g'))[1]
  loop
    select id into mentioned_id from public.profiles where lower(username) = lower(username_match) limit 1;
    perform public.create_notification(mentioned_id, new.user_id, 'mention', case when tg_table_name = 'posts' then new.id else new.post_id end, case when tg_table_name = 'comments' then new.id else null end);
  end loop;
  return new;
end;
$$;

create or replace function public.notify_friend_request() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'pending' then
    perform public.create_notification(new.receiver_id, new.sender_id, 'friend_request');
  end if;
  return new;
end;
$$;

create or replace function public.notify_new_message() returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.create_notification(new.receiver_id, new.sender_id, 'message');
  return new;
end;
$$;

drop trigger if exists notify_like on public.post_likes;
create trigger notify_like after insert on public.post_likes for each row execute function public.notify_new_like();
drop trigger if exists notify_comment on public.comments;
create trigger notify_comment after insert on public.comments for each row execute function public.notify_new_comment();
drop trigger if exists notify_post_mentions on public.posts;
create trigger notify_post_mentions after insert on public.posts for each row execute function public.notify_mentions();
drop trigger if exists notify_comment_mentions on public.comments;
create trigger notify_comment_mentions after insert on public.comments for each row execute function public.notify_mentions();
drop trigger if exists notify_friend_request on public.friendships;
create trigger notify_friend_request after insert on public.friendships for each row execute function public.notify_friend_request();
drop trigger if exists notify_direct_message on public.direct_messages;
create trigger notify_direct_message after insert on public.direct_messages for each row execute function public.notify_new_message();

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications') then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
end $$;
