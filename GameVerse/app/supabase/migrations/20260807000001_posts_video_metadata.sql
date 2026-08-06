-- Add video thumbnail and duration columns to public.posts table
alter table public.posts
  add column if not exists thumbnail_url text,
  add column if not exists duration text;

-- Create index for performance
create index if not exists posts_video_metadata_idx
  on public.posts (thumbnail_url, duration)
  where video is not null;
