-- Existing objects were being served with Cache-Control: no-cache, forcing the
-- browser to request multi-megabyte design assets on every visit. Public media
-- uses versioned paths (or app_settings.updated_at in the client), so a long
-- browser TTL is safe and drastically reduces cached egress.
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
)
and coalesce(metadata->>'cacheControl', '') <> '31536000';
