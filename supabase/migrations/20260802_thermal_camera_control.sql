create table if not exists public.thermal_camera_devices (
  device_id text primary key,
  actual_state text not null default 'unknown'
    check (actual_state in ('on', 'off', 'error', 'unknown')),
  last_seen timestamptz,
  last_error text,
  updated_at timestamptz not null default now()
);

create table if not exists public.thermal_camera_commands (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  desired_state text not null check (desired_state in ('on', 'off')),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'applied', 'failed', 'superseded')),
  requested_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  error_message text
);

create index if not exists thermal_camera_commands_device_status_requested_idx
  on public.thermal_camera_commands (device_id, status, requested_at);

alter table public.thermal_camera_devices enable row level security;
alter table public.thermal_camera_commands enable row level security;
