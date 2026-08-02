-- Sistema de experiencia persistente para Nubzzz.
-- Publicar +25 XP, comentar +10 XP, dar like +2 XP y añadir juego +20 XP.
alter table public.profiles
  add column if not exists xp integer not null default 0 check (xp >= 0),
  add column if not exists level integer not null default 1 check (level >= 1);

create table if not exists public.xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  source_id text not null,
  amount integer not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique (user_id, event_type, source_id)
);

alter table public.xp_events enable row level security;
drop policy if exists "Users can read their own XP events" on public.xp_events;
create policy "Users can read their own XP events"
  on public.xp_events for select to authenticated using (auth.uid() = user_id);

-- Cada nivel requiere 250 XP. El registro único impide ganar XP duplicado.
create or replace function public.award_xp(p_user_id uuid, p_amount integer, p_event_type text, p_source_id text)
returns void language plpgsql security definer set search_path = public as $$
declare v_event_id uuid; v_xp integer;
begin
  if p_user_id is null or p_amount <= 0 then return; end if;
  insert into public.xp_events (user_id, event_type, source_id, amount)
  values (p_user_id, p_event_type, p_source_id, p_amount)
  on conflict (user_id, event_type, source_id) do nothing returning id into v_event_id;
  if v_event_id is null then return; end if;
  update public.profiles set xp = coalesce(xp, 0) + p_amount where id = p_user_id returning xp into v_xp;
  update public.profiles set level = greatest(1, floor(coalesce(v_xp, 0) / 250.0)::integer + 1) where id = p_user_id;
end;
$$;

create or replace function public.xp_for_new_post() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.award_xp(new.user_id, 25, 'post', new.id::text); return new; end; $$;
create or replace function public.xp_for_new_comment() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.award_xp(new.user_id, 10, 'comment', new.id::text); return new; end; $$;
create or replace function public.xp_for_new_like() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.award_xp(new.user_id, 2, 'like', new.id::text); return new; end; $$;
create or replace function public.xp_for_new_game() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.award_xp(new.user_id, 20, 'game', new.id::text); return new; end; $$;

drop trigger if exists award_xp_for_post on public.posts;
create trigger award_xp_for_post after insert on public.posts for each row execute function public.xp_for_new_post();
drop trigger if exists award_xp_for_comment on public.comments;
create trigger award_xp_for_comment after insert on public.comments for each row execute function public.xp_for_new_comment();
drop trigger if exists award_xp_for_like on public.post_likes;
create trigger award_xp_for_like after insert on public.post_likes for each row execute function public.xp_for_new_like();
drop trigger if exists award_xp_for_game on public.user_games;
create trigger award_xp_for_game after insert on public.user_games for each row execute function public.xp_for_new_game();
