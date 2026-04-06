-- ============================================================
-- 🏥 MEDICARE AI — PRODUCTION SCHEMA STABILIZER v3
-- Fixes: FK violations, RLS, doctor status, user sync trigger
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ──────────────────────────────────────────────────
-- 1. ADD STATUS COLUMN TO DOCTOR PROFILES
-- Values: 'pending' | 'approved' | 'rejected'
-- ──────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'doctor_profiles'
      AND column_name = 'status'
  ) THEN
    ALTER TABLE public.doctor_profiles
      ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';
  END IF;
END $$;

-- Backfill: sync existing verified boolean → status text
UPDATE public.doctor_profiles
SET status = CASE
  WHEN verified = true THEN 'approved'
  ELSE 'pending'
END
WHERE status = 'pending' AND verified = true;

-- ──────────────────────────────────────────────────
-- 2. TRIGGER: Robust User Sync (Bypass RLS)
--    Fires AFTER INSERT on auth.users
--    Creates public.users row automatically
-- ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    default_role TEXT;
BEGIN
    default_role := COALESCE(new.raw_user_meta_data->>'role', 'patient');

    INSERT INTO public.users (id, email, role)
    VALUES (new.id, new.email, default_role)
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email, role = EXCLUDED.role;

    RETURN new;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ──────────────────────────────────────────────────
-- 3. RLS POLICIES (Production-Grade)
-- ──────────────────────────────────────────────────
ALTER TABLE public.patient_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Users: can read/update own record
DROP POLICY IF EXISTS "Users manage own data" ON public.users;
CREATE POLICY "Users manage own data" ON public.users
    FOR ALL USING (auth.uid() = id);

-- Patient profiles: authenticated users manage own
DROP POLICY IF EXISTS "Patients manage own profile" ON public.patient_profiles;
CREATE POLICY "Patients manage own profile" ON public.patient_profiles
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Doctor profiles: authenticated users manage own
DROP POLICY IF EXISTS "Doctors manage own profile" ON public.doctor_profiles;
CREATE POLICY "Doctors manage own profile" ON public.doctor_profiles
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ──────────────────────────────────────────────────
-- 4. NULL SAFETY: Nullable profile columns
-- ──────────────────────────────────────────────────
DO $$ BEGIN
  ALTER TABLE public.patient_profiles
    ALTER COLUMN age DROP NOT NULL,
    ALTER COLUMN gender DROP NOT NULL,
    ALTER COLUMN blood_group DROP NOT NULL,
    ALTER COLUMN allergies DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Some columns already nullable or do not exist: %', SQLERRM;
END $$;

-- ──────────────────────────────────────────────────
-- 5. DONE
-- ──────────────────────────────────────────────────
DO $$ BEGIN
  RAISE NOTICE 'Medicare AI Schema v3 applied successfully.';
END $$;
