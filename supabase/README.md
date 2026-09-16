# TowerAid Supabase setup

1. Create a Supabase project.
2. Open **SQL Editor**.
3. Run `supabase/migrations/001_initial_schema.sql`.
4. Enable the authentication provider you want (Phone OTP is recommended for the MVP).
5. Copy the project URL and **anon/publishable key** into the Flutter app configuration.

## Important

Do not put a Supabase `service_role`/secret key in the Flutter application. Server-side administrative actions should use Supabase Edge Functions or another trusted backend.

The migration enables Row Level Security and starts with privacy-first policies. Before production, review every policy with the society's access model and add server-side functions for emergency creation, escalation, FCM notification delivery, and audit logging.
