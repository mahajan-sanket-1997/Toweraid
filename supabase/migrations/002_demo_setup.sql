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


-- Phase 2 onboarding API
create or replace function public.get_registration_options()
returns table(society_id uuid,society_name text,building_id uuid,building_name text,floor_id uuid,floor_number int,flat_id uuid,flat_number text)
language sql security definer set search_path=public as $$ select s.id,s.name,b.id,b.name,f.id,f.floor_number,fl.id,fl.flat_number from public.societies s join public.buildings b on b.society_id=s.id join public.floors f on f.building_id=b.id join public.flats fl on fl.floor_id=f.id order by s.name,b.name,f.floor_number,fl.flat_number $$;
grant execute on function public.get_registration_options() to authenticated;
create or replace function public.complete_resident_registration(society_id_input uuid,building_id_input uuid,floor_id_input uuid,flat_id_input uuid,resident_type_input public.resident_type)
returns uuid language plpgsql security definer set search_path=public as $$ declare resident_id uuid; begin if auth.uid() is null then raise exception 'Authentication required'; end if; if not exists(select 1 from public.flats fl join public.floors f on f.id=fl.floor_id join public.buildings b on b.id=f.building_id where fl.id=flat_id_input and f.id=floor_id_input and b.id=building_id_input and b.society_id=society_id_input) then raise exception 'Invalid society, tower, floor or flat selection'; end if; insert into public.profiles(id,full_name,phone) values(auth.uid(),coalesce(auth.jwt()->'user_metadata'->>'full_name',auth.jwt()->>'email'),auth.jwt()->>'email') on conflict(id) do update set full_name=coalesce(public.profiles.full_name,excluded.full_name),phone=coalesce(public.profiles.phone,excluded.phone); select id into resident_id from public.residents where user_id=auth.uid() limit 1; if resident_id is null then insert into public.residents(user_id,flat_id,resident_type,is_primary,verification_status) values(auth.uid(),flat_id_input,resident_type_input,true,'VERIFIED') returning id into resident_id; else update public.residents set flat_id=flat_id_input,resident_type=resident_type_input,is_primary=true where id=resident_id; end if; return resident_id; end; $$;
grant execute on function public.complete_resident_registration(uuid,uuid,uuid,uuid,public.resident_type) to authenticated;
create or replace function public.get_my_resident_context()
returns table(resident_id uuid,society_id uuid,society_name text,building_id uuid,building_name text,floor_id uuid,floor_number int,flat_id uuid,flat_number text,resident_type public.resident_type,verification_status public.verification_status,full_name text,email text)
language sql security definer set search_path=public as $$ select r.id,s.id,s.name,b.id,b.name,f.id,f.floor_number,fl.id,fl.flat_number,r.resident_type,r.verification_status,p.full_name,u.email from public.residents r join public.flats fl on fl.id=r.flat_id join public.floors f on f.id=fl.floor_id join public.buildings b on b.id=f.building_id join public.societies s on s.id=b.society_id join auth.users u on u.id=r.user_id left join public.profiles p on p.id=r.user_id where r.user_id=auth.uid() limit 1 $$;
grant execute on function public.get_my_resident_context() to authenticated;
