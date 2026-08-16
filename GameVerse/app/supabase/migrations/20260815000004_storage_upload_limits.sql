-- Enforce upload limits at Storage level as well as in the Flutter client.
-- Existing objects are preserved; these limits apply only to future uploads.

update storage.buckets
set file_size_limit = 5242880 -- 5 MiB
where id in ('post-images', 'post-thumbnails', 'avatars');

update storage.buckets
set file_size_limit = 10485760 -- 10 MiB
where id = 'banners';

update storage.buckets
set file_size_limit = 26214400 -- 25 MiB
where id = 'post-videos';
