-- Create RLS update policy for voice_channels to allow creators and invitees to modify the channel (e.g. status)
drop policy if exists "Allow updating voice channels" on public.voice_channels;
create policy "Allow updating voice channels"
on public.voice_channels for update to authenticated
using (
  created_by = auth.uid() 
  or invitee_id = auth.uid()
)
with check (
  created_by = auth.uid() 
  or invitee_id = auth.uid()
);
