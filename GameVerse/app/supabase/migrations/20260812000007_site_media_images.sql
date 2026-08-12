update storage.buckets
set allowed_mime_types = array['video/mp4', 'video/quicktime', 'image/png', 'image/jpeg', 'image/webp']
where id = 'site-media';
