-- Create post-thumbnails storage bucket if it does not exist
insert into storage.buckets (id, name, public)
values ('post-thumbnails', 'post-thumbnails', true)
on conflict (id) do nothing;

-- Set up Storage Policies for post-thumbnails bucket (matching post-videos and post-images)
drop policy if exists "Post thumbnails public read" on storage.objects;
create policy "Post thumbnails public read"
on storage.objects for select to public
using (bucket_id = 'post-thumbnails');

drop policy if exists "Post thumbnails auth insert" on storage.objects;
create policy "Post thumbnails auth insert"
on storage.objects for insert to authenticated
with check (bucket_id = 'post-thumbnails');

drop policy if exists "Post thumbnails auth delete" on storage.objects;
create policy "Post thumbnails auth delete"
on storage.objects for delete to authenticated
using (bucket_id = 'post-thumbnails');
