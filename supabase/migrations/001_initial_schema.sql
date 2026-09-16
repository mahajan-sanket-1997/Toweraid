-- TowerAid Supabase schema
create extension if not exists pgcrypto;

create type public.resident_type as enum ('OWNER','TENANT','FAMILY_MEMBER');
create type public.verification_status as enum ('PENDING','VERIFIED','REJECTED');
create type public.emergency_type as enum ('FIRE','MEDICAL','LIFT','GAS_LEAK','ACCIDENT','OTHER');
create type public.emergency_status as enum ('ACTIVE','ACKNOWLEDGED','RESOLVED','CANCELLED');
create type public.response_status as enum ('SAFE','NEED_HELP','NO_RESPONSE','EVACUATED','ASSISTED');
create type public.assistance_status as enum ('OPEN','ASSIGNED','IN_PROGRESS','RESOLVED','CANCELLED');
create type public.app_role as enum ('SUPER_ADMIN','SOCIETY_ADMIN','SECURITY_SUPERVISOR','SECURITY_GUARD','RESIDENT');

create table public.societies (
  id uuid primary key default gen_random_uuid(), name text not null, address text, city text, state text, country text default 'India', emergency_phone text, created_at timestamptz not null default now()
);
create table public.buildings (
  id uuid primary key default gen_random_uuid(), society_id uuid not null references public.societies(id) on delete cascade, name text not null, number_of_floors int default 0, number_of_flats int default 0, created_at timestamptz not null default now()
);
create table public.floors (
  id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id) on delete cascade, floor_number int not null, unique(building_id,floor_number)
);
create table public.flats (
  id uuid primary key default gen_random_uuid(), floor_id uuid not null references public.floors(id) on delete cascade, flat_number text not null, unique(floor_id,flat_number)
);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade, full_name text, phone text, created_at timestamptz not null default now()
);
create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade, role public.app_role not null, society_id uuid references public.societies(id) on delete cascade, primary key(user_id,role,society_id)
);
create table public.residents (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, flat_id uuid not null references public.flats(id) on delete cascade, resident_type public.resident_type not null, is_primary boolean default false, verification_status public.verification_status default 'PENDING', created_at timestamptz not null default now()
);
create table public.occupants (
  id uuid primary key default gen_random_uuid(), flat_id uuid not null references public.flats(id) on delete cascade, name text not null, relationship text, vulnerable boolean default false, notes text
);
create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(), resident_id uuid not null references public.residents(id) on delete cascade, name text not null, relationship text, phone text not null
);
create table public.security_staff (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, society_id uuid not null references public.societies(id) on delete cascade, name text not null, phone text, role public.app_role not null
);
create table public.emergencies (
  id uuid primary key default gen_random_uuid(), society_id uuid not null references public.societies(id) on delete cascade, reported_by uuid not null references auth.users(id), building_id uuid references public.buildings(id), floor_id uuid references public.floors(id), flat_id uuid references public.flats(id), type public.emergency_type not null, description text, status public.emergency_status not null default 'ACTIVE', created_at timestamptz not null default now(), acknowledged_at timestamptz, resolved_at timestamptz
);
create table public.emergency_responses (
  id uuid primary key default gen_random_uuid(), emergency_id uuid not null references public.emergencies(id) on delete cascade, resident_id uuid not null references public.residents(id) on delete cascade, status public.response_status not null, response_time timestamptz not null default now(), notes text, unique(emergency_id,resident_id)
);
create table public.assistance_requests (
  id uuid primary key default gen_random_uuid(), emergency_id uuid not null references public.emergencies(id) on delete cascade, flat_id uuid references public.flats(id), resident_id uuid references public.residents(id), type text not null, priority int default 1, description text, assigned_to uuid references public.security_staff(id), status public.assistance_status not null default 'OPEN', created_at timestamptz not null default now(), resolved_at timestamptz
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, emergency_id uuid references public.emergencies(id) on delete cascade, title text not null, message text not null, type text, delivered_at timestamptz, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.devices (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, device_token text not null unique, platform text, last_seen timestamptz default now()
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(), society_id uuid references public.societies(id) on delete cascade, actor_user_id uuid references auth.users(id), action text not null, entity_type text, entity_id uuid, metadata jsonb default '{}'::jsonb, created_at timestamptz not null default now()
);

create or replace function public.is_society_member(target_society uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.user_roles r where r.user_id=auth.uid() and r.society_id=target_society)
  or exists(select 1 from public.residents r join public.flats f on f.id=r.flat_id join public.floors fl on fl.id=f.floor_id join public.buildings b on b.id=fl.building_id where r.user_id=auth.uid() and b.society_id=target_society);
$$;

create or replace function public.has_role(target_role public.app_role, target_society uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.user_roles r where r.user_id=auth.uid() and r.role=target_role and r.society_id=target_society);
$$;

alter table public.societies enable row level security;
alter table public.buildings enable row level security;
alter table public.floors enable row level security;
alter table public.flats enable row level security;
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.residents enable row level security;
alter table public.occupants enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.security_staff enable row level security;
alter table public.emergencies enable row level security;
alter table public.emergency_responses enable row level security;
alter table public.assistance_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.devices enable row level security;
alter table public.audit_logs enable row level security;

create policy "members read society" on public.societies for select using (public.is_society_member(id));
create policy "members read buildings" on public.buildings for select using (public.is_society_member(society_id));
create policy "members read floors" on public.floors for select using (exists(select 1 from public.buildings b where b.id=building_id and public.is_society_member(b.society_id)));
create policy "members read flats" on public.flats for select using (exists(select 1 from public.floors f join public.buildings b on b.id=f.building_id where f.id=floor_id and public.is_society_member(b.society_id)));
create policy "own profile" on public.profiles for all using (id=auth.uid()) with check (id=auth.uid());
create policy "own roles read" on public.user_roles for select using (user_id=auth.uid());
create policy "own resident read" on public.residents for select using (user_id=auth.uid());
create policy "resident read own occupants" on public.occupants for select using (exists(select 1 from public.residents r where r.user_id=auth.uid() and r.flat_id=flat_id));
create policy "resident read own contacts" on public.emergency_contacts for select using (exists(select 1 from public.residents r where r.id=resident_id and r.user_id=auth.uid()));
create policy "members read security" on public.security_staff for select using (public.is_society_member(society_id));
create policy "residents create emergency" on public.emergencies for insert with check (reported_by=auth.uid() and public.is_society_member(society_id));
create policy "members read emergencies" on public.emergencies for select using (public.is_society_member(society_id));
create policy "members update emergencies" on public.emergencies for update using (public.is_society_member(society_id));
create policy "members read responses" on public.emergency_responses for select using (exists(select 1 from public.emergencies e where e.id=emergency_id and public.is_society_member(e.society_id)));
create policy "own response write" on public.emergency_responses for all using (exists(select 1 from public.residents r where r.id=resident_id and r.user_id=auth.uid())) with check (exists(select 1 from public.residents r where r.id=resident_id and r.user_id=auth.uid()));
create policy "members read assistance" on public.assistance_requests for select using (exists(select 1 from public.emergencies e where e.id=emergency_id and public.is_society_member(e.society_id)));
create policy "members write assistance" on public.assistance_requests for all using (exists(select 1 from public.emergencies e where e.id=emergency_id and public.is_society_member(e.society_id)));
create policy "own notifications" on public.notifications for select using (user_id=auth.uid());
create policy "own notifications update" on public.notifications for update using (user_id=auth.uid());
create policy "own devices" on public.devices for all using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy "admins read audit" on public.audit_logs for select using (public.has_role('SOCIETY_ADMIN',society_id) or public.has_role('SUPER_ADMIN',society_id));

create index emergencies_society_status_idx on public.emergencies(society_id,status,created_at desc);
create index emergencies_flat_idx on public.emergencies(flat_id,created_at desc);
create index residents_user_idx on public.residents(user_id);
create index residents_flat_idx on public.residents(flat_id);
create index notifications_user_idx on public.notifications(user_id,created_at desc);
