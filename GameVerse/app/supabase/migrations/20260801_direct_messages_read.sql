drop policy if exists "Users mark received messages as read" on public.direct_messages;

create policy "Users mark received messages as read"
  on public.direct_messages for update to authenticated
  using (auth.uid() = receiver_id)
  with check (auth.uid() = receiver_id);
