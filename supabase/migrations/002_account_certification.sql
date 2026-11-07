-- 002 — Certification du compte (CNI, téléphone) — idempotent.
-- À exécuter dans Supabase > SQL Editor.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS cni_status text NOT NULL DEFAULT 'none';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS cni_verified boolean NOT NULL DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT false;

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_cni_status_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_cni_status_check
  CHECK (cni_status IN ('none', 'pending', 'verified', 'rejected'));

-- Un utilisateur ne peut pas se certifier lui-même : depuis l'app il peut
-- seulement passer cni_status à 'none' ou 'pending'. 'verified' / 'rejected',
-- cni_verified et is_verified se changent depuis le SQL Editor ou le
-- service role (auth.uid() est alors NULL).
CREATE OR REPLACE FUNCTION protect_profile_verification()
RETURNS trigger AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.cni_verified := OLD.cni_verified;
    NEW.is_verified  := OLD.is_verified;
    IF NEW.cni_status IS DISTINCT FROM OLD.cni_status
       AND NEW.cni_status NOT IN ('none', 'pending') THEN
      NEW.cni_status := OLD.cni_status;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_profile_verification ON profiles;
CREATE TRIGGER trg_protect_profile_verification
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION protect_profile_verification();

-- Bucket PRIVÉ pour les photos de CNI : chacun n'accède qu'à son dossier.
INSERT INTO storage.buckets (id, name, public)
VALUES ('identity-documents', 'identity-documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "CNI lecture propriétaire" ON storage.objects;
DROP POLICY IF EXISTS "CNI envoi propriétaire" ON storage.objects;
DROP POLICY IF EXISTS "CNI mise à jour propriétaire" ON storage.objects;

CREATE POLICY "CNI lecture propriétaire"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'identity-documents'
         AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "CNI envoi propriétaire"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'identity-documents'
              AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "CNI mise à jour propriétaire"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'identity-documents'
         AND (storage.foldername(name))[1] = auth.uid()::text);
