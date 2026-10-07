-- AllCommerce · 0010 · Device tokens for push notifications

create table public.user_devices (
  fcm_token text primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  platform text not null default 'unknown',
  updated_at timestamptz not null default now()
);

create index user_devices_user_id_idx on public.user_devices (user_id);

-- Users can upsert their own tokens, delete old ones.
alter table public.user_devices enable row level security;

create policy user_devices_insert_update_own
  on public.user_devices
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
