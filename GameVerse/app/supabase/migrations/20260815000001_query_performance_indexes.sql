-- Query-performance indexes for the production read paths.
--
-- This migration is additive: it does not alter or delete application data,
-- policies, triggers, or table definitions. Each index matches a query used by
-- the Flutter client, so PostgreSQL can avoid sorting/scanning growing tables.
-- `IF NOT EXISTS` makes the migration safe to retry.

-- Feed, profile wall, and clan wall.
create index if not exists posts_created_at_desc_idx
  on public.posts (created_at desc);

create index if not exists posts_user_created_at_desc_idx
  on public.posts (user_id, created_at desc);

create index if not exists posts_clan_created_at_desc_idx
  on public.posts (clan_id, created_at desc)
  where clan_id is not null;

-- Both directions are queried for friendship lookups and friend feeds.
create index if not exists friendships_sender_status_idx
  on public.friendships (sender_id, status);

create index if not exists friendships_receiver_status_idx
  on public.friendships (receiver_id, status);

-- Conversations are read in either participant direction and sorted by time.
-- The existing sender/receiver index covers one direction; this covers the
-- inverse direction without changing the messaging model.
create index if not exists direct_messages_receiver_sender_created_idx
  on public.direct_messages (receiver_id, sender_id, created_at);

-- Inbox and unread-message updates filter by recipient and read state.
create index if not exists direct_messages_receiver_created_idx
  on public.direct_messages (receiver_id, created_at desc);

create index if not exists direct_messages_unread_receiver_sender_idx
  on public.direct_messages (receiver_id, sender_id)
  where read_at is null;

-- Personal library and profile sidebar queries filter by owner.
create index if not exists user_games_user_created_at_desc_idx
  on public.user_games (user_id, created_at desc);

-- Live-stream chat is loaded by stream in chronological order.
create index if not exists live_stream_messages_stream_created_idx
  on public.live_stream_messages (stream_id, created_at);
