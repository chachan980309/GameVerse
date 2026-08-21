-- Refresh the object metadata timestamp so Storage's metadata cache observes
-- the browser cache-control value changed by the previous migration.
update storage.objects
set metadata = jsonb_set(
      coalesce(metadata, '{}'::jsonb),
      '{cacheControl}',
      '"31536000"'::jsonb,
      true
    ),
    updated_at = now()
where bucket_id in (
  'app-assets',
  'site-media',
  'post-images',
  'post-thumbnails',
  'avatars',
  'clans',
  'tournament-images'
);
