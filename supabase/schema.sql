create table if not exists public.task_groups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  sort_order integer not null default 0,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, id)
);

create unique index if not exists task_groups_user_name_idx
  on public.task_groups (user_id, lower(name));

create table if not exists public.tasks (
  id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  notes text not null default '' check (char_length(notes) <= 1000),
  category text not null default 'work',
  group_id uuid references public.task_groups (id) on delete set null,
  series_id text,
  done boolean not null default false,
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'done')),
  due_date date,
  schedule_date date,
  start_time time,
  deadline_time time,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  minutes integer not null default 25 check (minutes between 5 and 600),
  actual_minutes integer check (actual_minutes is null or actual_minutes between 0 and 6000),
  recurrence text not null default 'none' check (recurrence in ('none', 'daily', 'weekdays', 'weekly', 'weekly_custom', 'monthly')),
  recurrence_until date,
  recurrence_days smallint[] not null default '{}',
  certainty text not null default 'confirmed' check (certainty in ('confirmed', 'tentative')),
  conflict_policy text not null default 'prefer' check (conflict_policy in ('allow', 'prefer', 'strict')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  reminder_notified text not null default '',
  primary key (user_id, id)
);

alter table public.tasks add column if not exists group_id uuid references public.task_groups (id) on delete set null;
alter table public.tasks add column if not exists series_id text;
alter table public.tasks add column if not exists status text not null default 'todo';
alter table public.tasks add column if not exists actual_minutes integer;
alter table public.tasks add column if not exists recurrence text not null default 'none';
alter table public.tasks add column if not exists recurrence_until date;
alter table public.tasks add column if not exists recurrence_days smallint[] not null default '{}';
alter table public.tasks add column if not exists certainty text not null default 'confirmed';
alter table public.tasks add column if not exists conflict_policy text not null default 'prefer';
alter table public.tasks drop constraint if exists tasks_category_check;
alter table public.tasks drop constraint if exists tasks_status_check;
alter table public.tasks add constraint tasks_status_check check (status in ('todo', 'in_progress', 'done'));
alter table public.tasks drop constraint if exists tasks_actual_minutes_check;
alter table public.tasks add constraint tasks_actual_minutes_check check (actual_minutes is null or actual_minutes between 0 and 6000);
alter table public.tasks drop constraint if exists tasks_recurrence_check;
alter table public.tasks add constraint tasks_recurrence_check check (recurrence in ('none', 'daily', 'weekdays', 'weekly', 'weekly_custom', 'monthly'));
alter table public.tasks drop constraint if exists tasks_recurrence_days_check;
alter table public.tasks add constraint tasks_recurrence_days_check check (
  (recurrence = 'weekly_custom' and cardinality(recurrence_days) between 1 and 7)
  or (recurrence <> 'weekly_custom' and cardinality(recurrence_days) = 0)
);
alter table public.tasks drop constraint if exists tasks_certainty_check;
alter table public.tasks add constraint tasks_certainty_check check (certainty in ('confirmed', 'tentative'));
alter table public.tasks drop constraint if exists tasks_conflict_policy_check;
alter table public.tasks add constraint tasks_conflict_policy_check check (conflict_policy in ('allow', 'prefer', 'strict'));
update public.tasks set status = 'done' where done and status = 'todo';
update public.tasks set done = (status = 'done') where done is distinct from (status = 'done');

create index if not exists tasks_user_schedule_idx
  on public.tasks (user_id, schedule_date, start_time);

create index if not exists tasks_user_series_schedule_idx
  on public.tasks (user_id, series_id, schedule_date);

create index if not exists tasks_user_deadline_idx
  on public.tasks (user_id, due_date, done);

alter table public.tasks enable row level security;
alter table public.task_groups enable row level security;

grant select, insert, update, delete on public.tasks to authenticated;
grant select, insert, update, delete on public.task_groups to authenticated;

drop policy if exists "Users can read their own task groups" on public.task_groups;
create policy "Users can read their own task groups"
  on public.task_groups for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own task groups" on public.task_groups;
create policy "Users can create their own task groups"
  on public.task_groups for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own task groups" on public.task_groups;
create policy "Users can update their own task groups"
  on public.task_groups for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own task groups" on public.task_groups;
create policy "Users can delete their own task groups"
  on public.task_groups for delete
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can read their own tasks" on public.tasks;
create policy "Users can read their own tasks"
  on public.tasks for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own tasks" on public.tasks;
create policy "Users can create their own tasks"
  on public.tasks for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and (group_id is null or exists (
      select 1 from public.task_groups
      where task_groups.id = tasks.group_id and task_groups.user_id = (select auth.uid())
    ))
  );

drop policy if exists "Users can update their own tasks" on public.tasks;
create policy "Users can update their own tasks"
  on public.tasks for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (group_id is null or exists (
      select 1 from public.task_groups
      where task_groups.id = tasks.group_id and task_groups.user_id = (select auth.uid())
    ))
  );

drop policy if exists "Users can delete their own tasks" on public.tasks;
create policy "Users can delete their own tasks"
  on public.tasks for delete
  to authenticated
  using ((select auth.uid()) = user_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'tasks'
  ) then
    alter publication supabase_realtime add table public.tasks;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'task_groups'
  ) then
    alter publication supabase_realtime add table public.task_groups;
  end if;
end
$$;