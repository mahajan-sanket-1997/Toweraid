-- Enable Realtime for the emergency table.
-- Run this after 001_initial_schema.sql in the Supabase SQL Editor.

alter table public.emergencies replica identity full;

-- Safe to run repeatedly: remove the table from the publication first if present.
do $$
begin
  begin
    alter publication supabase_realtime drop table public.emergencies;
  exception when undefined_object then
    null;
  end;
  alter publication supabase_realtime add table public.emergencies;
exception when duplicate_object then
  null;
end $$;
