create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (sender_id <> receiver_id)
);

create index if not exists direct_messages_conversation_idx
  on public.direct_messages (sender_id, receiver_id, created_at);

alter table public.direct_messages enable row level security;

drop policy if exists "Users read their direct messages" on public.direct_messages;
drop policy if exists "Users send their own direct messages" on public.direct_messages;

create policy "Users read their direct messages"
  on public.direct_messages for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Users send their own direct messages"
  on public.direct_messages for insert
  with check (auth.uid() = sender_id);
