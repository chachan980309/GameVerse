-- Add advanced video metadata columns to public.posts table
alter table public.posts
  add column if not exists width integer,
  add column if not exists height integer,
  add column if not exists aspect_ratio double precision;

-- Create index for performance
create index if not exists posts_video_dimensions_idx
  on public.posts (width, height, aspect_ratio)
  where video is not null;
