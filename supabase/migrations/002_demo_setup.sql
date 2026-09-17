-- Development-only demo data for testing TowerAid realtime emergency flow.
-- Do NOT use this seed/claim function in production without replacing it with
-- proper authenticated society onboarding and admin verification.

insert into public.societies (id, name, address, city, state, country, emergency_phone)
values ('00000000-0000-0000-0000-000000000001', 'TowerAid Demo Society', 'Demo Address', 'Pune', 'Maharashtra', 'India', '0000000000')
on conflict (id) do nothing;

insert into public.buildings (id, society_id, name, number_of_floors, number_of_flats)
values ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Tower A', 22, 484)
on conflict (id) do nothing;

insert into public.floors (id, building_id, floor_number)
values ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 9)
on conflict (id) do nothing;

insert into public.flats (id, floor_id, flat_number)
values ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '904')
on conflict (id) do nothing;

-- Development helper: creates/updates the current authenticated user's demo resident.
-- Production onboarding must replace this with verified society-admin approval.
create or replace function public.claim_demo_flat(full_name_input text, phone_input text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare resident_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.profiles (id, full_name, phone)
  values (auth.uid(), full_name_input, phone_input)
  on conflict (id) do update set full_name = excluded.full_name, phone = excluded.phone;

  insert into public.residents (user_id, flat_id, resident_type, is_primary, verification_status)
  values (auth.uid(), '00000000-0000-0000-0000-000000000004', 'OWNER', true, 'VERIFIED')
  on conflict do nothing
  returning id into resident_id;

  if resident_id is null then
    select id into resident_id from public.residents
    where user_id = auth.uid() and flat_id = '00000000-0000-0000-0000-000000000004'
    limit 1;
  end if;

  return resident_id;
end;
$$;

grant execute on function public.claim_demo_flat(text,text) to authenticated;

-- Allow the demo resident to create an emergency for the demo society.
-- This is intentionally development-only and should be replaced by normal
-- society membership/RLS once real onboarding is implemented.
