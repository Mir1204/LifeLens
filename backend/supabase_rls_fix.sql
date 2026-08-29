-- Defense in depth for Supabase. The FastAPI service should connect with a
-- dedicated service role; browser/mobile clients must never access these tables.
ALTER TABLE public.daily_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backend_users ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.daily_entries FROM anon, authenticated;
REVOKE ALL ON TABLE public.backend_users FROM anon, authenticated;

-- No SELECT/INSERT/UPDATE/DELETE policies are created intentionally: direct
-- client access is denied. FastAPI authorizes each request using its JWT.
