-- 1. Drop existing status check constraint on tournaments table and add updated check constraint supporting 'full' and 'archived' statuses
do $$
declare
  con_name text;
begin
  select constraint_name into con_name
  from information_schema.constraint_column_usage
  where table_name = 'tournaments' and column_name = 'status'
  limit 1;
  if con_name is not null then
    execute 'alter table public.tournaments drop constraint ' || quote_ident(con_name);
  end if;
end $$;

alter table public.tournaments 
  add constraint tournaments_status_check 
  check (status in ('draft', 'registration', 'full', 'in_progress', 'finished', 'cancelled', 'archived'));

-- 2. Add marked_for_review column to tournaments
alter table public.tournaments
  add column if not exists marked_for_review boolean not null default false;

-- 3. Create unique index to prevent duplicate tournaments from the same user
create unique index if not exists tournaments_user_duplicate_idx
  on public.tournaments (creator_id, game_name, start_date, lower(name));

-- 4. Create tournament_reports table
create table if not exists public.tournament_reports (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('spam', 'offensive', 'fake_info', 'scam', 'other')),
  details text,
  created_at timestamptz not null default now(),
  unique (tournament_id, reporter_id)
);

-- Enable RLS on tournament_reports
alter table public.tournament_reports enable row level security;

-- Policies for tournament_reports
drop policy if exists "Authenticated users can read tournament reports" on public.tournament_reports;
create policy "Authenticated users can read tournament reports"
on public.tournament_reports for select to authenticated
using (true);

drop policy if exists "Users can report tournaments" on public.tournament_reports;
create policy "Users can report tournaments"
on public.tournament_reports for insert to authenticated
with check (reporter_id = auth.uid());

-- 5. Trigger to automatically flag a tournament for review when it receives >= 5 reports
create or replace function public.flag_tournament_on_reports()
returns trigger as $$
declare
  report_count integer;
begin
  select count(*) into report_count from public.tournament_reports where tournament_id = new.tournament_id;
  if report_count >= 5 then
    update public.tournaments set marked_for_review = true where id = new.tournament_id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_flag_tournament on public.tournament_reports;
create trigger trigger_flag_tournament
after insert on public.tournament_reports
for each row execute function public.flag_tournament_on_reports();

-- 6. Trigger to prevent a user from having more than 5 active tournaments at the same time (spam protection)
create or replace function public.check_user_tournament_spam()
returns trigger as $$
declare
  active_count integer;
begin
  select count(*) into active_count 
  from public.tournaments 
  where creator_id = new.creator_id 
    and status in ('draft', 'registration', 'full', 'in_progress');
       
  if active_count >= 5 then
    raise exception 'Has alcanzado el límite de spam. Puedes tener como máximo 5 torneos activos al mismo tiempo.';
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_check_tournament_spam on public.tournaments;
create trigger trigger_check_tournament_spam
before insert on public.tournaments
for each row execute function public.check_user_tournament_spam();

-- 7. Update notifications table check constraint and add tournament_id column
do $$
declare
  con_name text;
begin
  select constraint_name into con_name
  from information_schema.constraint_column_usage
  where table_name = 'notifications' and column_name = 'type'
  limit 1;
  if con_name is not null then
    execute 'alter table public.notifications drop constraint ' || quote_ident(con_name);
  end if;
end $$;

alter table public.notifications
  add column if not exists tournament_id uuid references public.tournaments(id) on delete cascade;

alter table public.notifications
  add constraint notifications_type_check
  check (type in ('like', 'comment', 'mention', 'share', 'friend_request', 'message', 'tournament_cancelled', 'tournament_flagged'));

-- 8. Trigger to automatically notify all participants when a tournament is cancelled
create or replace function public.notify_participants_on_cancellation()
returns trigger as $$
declare
  participant_row record;
begin
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    for participant_row in (
      select user_id from public.tournament_participants where tournament_id = new.id
    ) loop
      insert into public.notifications (recipient_id, actor_id, type, tournament_id)
      values (participant_row.user_id, new.creator_id, 'tournament_cancelled', new.id);
    end loop;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trigger_notify_tournament_cancelled on public.tournaments;
create trigger trigger_notify_tournament_cancelled
after update of status on public.tournaments
for each row execute function public.notify_participants_on_cancellation();

-- 9. Create Organizer Stats View
create or replace view public.organizer_stats as
select 
  t.creator_id as organizer_id,
  count(distinct t.id) as created_count,
  count(distinct t.id) filter (where t.status = 'finished') as finished_count,
  count(distinct t.id) filter (where t.status = 'cancelled') as cancelled_count,
  count(distinct p.user_id) as total_participants,
  case 
    when count(distinct t.id) filter (where t.status in ('finished', 'cancelled')) = 0 then 5.0
    else round(5.0 * (count(distinct t.id) filter (where t.status = 'finished'))::numeric / count(distinct t.id) filter (where t.status in ('finished', 'cancelled')), 1)
  end as rating
from public.tournaments t
left join public.tournament_participants p on p.tournament_id = t.id
group by t.creator_id;

-- Ensure realtime updates are enabled for tournament_reports
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tournament_reports') then
    execute 'alter publication supabase_realtime add table public.tournament_reports';
  end if;
end $$;
