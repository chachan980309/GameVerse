-- Complete the cache metadata coverage for every immutable media bucket.
update storage.objects
set metadata = jsonb_set(
      coalesce(metadata, '{}'::jsonb),
      '{cacheControl}',
      '"31536000"'::jsonb,
      true
    ),
    updated_at = now()
where bucket_id in ('post-videos', 'banners');
