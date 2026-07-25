create extension if not exists "pgcrypto";

create table if not exists public.patient_profiles (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text unique,
  phone text,
  national_id text unique,
  date_of_birth date,
  gender text check (gender in ('male', 'female')),
  blood_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.doctor_profiles (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  specialty text not null,
  degree text,
  rating numeric(2, 1) default 4.8,
  years_experience integer default 0,
  clinic_name text,
  is_online boolean not null default true,
  working_start text default '09:00 AM',
  working_end text default '05:00 PM',
  working_days text[] default array['Su', 'Mo', 'Tu', 'We', 'Th'],
  languages text[] default array['English', 'Arabic'],
  certificates text[] default array[]::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists doctor_profiles_full_name_unique
  on public.doctor_profiles (lower(full_name));

alter table public.doctor_profiles
  add column if not exists working_start text default '09:00 AM';

alter table public.doctor_profiles
  add column if not exists working_end text default '05:00 PM';

alter table public.doctor_profiles
  add column if not exists working_days text[] default array['Su', 'Mo', 'Tu', 'We', 'Th'];

alter table public.doctor_profiles
  add column if not exists languages text[] default array['English', 'Arabic'];

alter table public.doctor_profiles
  add column if not exists certificates text[] default array[]::text[];

create table if not exists public.user_accounts (
  id uuid primary key default gen_random_uuid(),
  role text not null check (role in ('patient', 'doctor', 'admin')),
  patient_id uuid references public.patient_profiles(id) on delete cascade,
  doctor_id uuid references public.doctor_profiles(id) on delete cascade,
  email text,
  mobile text,
  national_id text,
  password_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_accounts_profile_check check (
    (role = 'patient' and patient_id is not null and doctor_id is null)
    or
    (role = 'doctor' and doctor_id is not null and patient_id is null)
    or
    (role = 'admin' and patient_id is null and doctor_id is null)
  )
);

do $$
begin
  alter table public.user_accounts
    drop constraint if exists user_accounts_role_check;
  alter table public.user_accounts
    add constraint user_accounts_role_check
    check (role in ('patient', 'doctor', 'admin'));
end $$;

do $$
begin
  alter table public.user_accounts
    drop constraint if exists user_accounts_profile_check;
  alter table public.user_accounts
    add constraint user_accounts_profile_check check (
      (role = 'patient' and patient_id is not null and doctor_id is null)
      or
      (role = 'doctor' and doctor_id is not null and patient_id is null)
      or
      (role = 'admin' and patient_id is null and doctor_id is null)
    );
end $$;

create unique index if not exists user_accounts_role_email_unique
  on public.user_accounts (role, lower(email))
  where email is not null;

create unique index if not exists user_accounts_role_mobile_unique
  on public.user_accounts (role, mobile)
  where mobile is not null;

create unique index if not exists user_accounts_role_national_id_unique
  on public.user_accounts (role, national_id)
  where national_id is not null;

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patient_profiles(id) on delete cascade,
  doctor_id uuid not null references public.doctor_profiles(id) on delete cascade,
  appointment_at timestamptz not null,
  date_label text,
  time_label text,
  reason text,
  notes text,
  visit_mode text not null default 'in_clinic' check (visit_mode in ('in_clinic', 'online')),
  ctas_level integer check (ctas_level between 1 and 5),
  status text not null default 'scheduled'
    check (status in ('scheduled', 'checked_in', 'in_clinic', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.appointments
  add column if not exists date_label text;

alter table public.appointments
  add column if not exists time_label text;

create table if not exists public.patient_vitals (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patient_profiles(id) on delete cascade,
  appointment_id uuid references public.appointments(id) on delete set null,
  vital_type text not null,
  value text not null,
  source text not null check (source in ('camera', 'app', 'device', 'manual')),
  approval_status text not null default 'pending'
    check (approval_status in ('pending', 'confirmed', 'retake_requested', 'rejected')),
  measured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.medications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patient_profiles(id) on delete cascade,
  name text not null,
  dose text,
  schedule text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patient_profiles(id) on delete cascade,
  doctor_id uuid not null references public.doctor_profiles(id) on delete cascade,
  sender_role text not null check (sender_role in ('patient', 'doctor')),
  body text not null,
  created_at timestamptz not null default now()
);

insert into public.doctor_profiles
  (full_name, specialty, degree, rating, years_experience, clinic_name)
values
  ('Dr. Ahmed Mohamed', 'General Physician', 'MBBS, MD', 4.9, 12, 'Care Medical Center'),
  ('Dr. Sara Al-Harbi', 'Cardiologist', 'MBBS, DM Cardio', 4.9, 9, 'Care Medical Center'),
  ('Dr. Yusuf Karim', 'Dermatologist', 'MBBS, MD Derm', 4.7, 7, 'Care Medical Center'),
  ('Dr. Layla Nasser', 'Pediatrician', 'MBBS, MD Peds', 4.9, 11, 'Care Medical Center')
on conflict do nothing;
