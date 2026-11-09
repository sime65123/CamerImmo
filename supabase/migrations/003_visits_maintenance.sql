-- 003 — Demandes de visite et signalements de maintenance — idempotent.
-- À exécuter dans Supabase > SQL Editor APRÈS 001 et 002.
-- Si une table existait déjà avec d'autres noms de colonnes obligatoires,
-- l'insertion échouera : envoyer le message d'erreur pour adapter.

CREATE TABLE IF NOT EXISTS visit_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS maintenance_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Colonnes utilisées par l'app
ALTER TABLE visit_requests
  ADD COLUMN IF NOT EXISTS property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS landlord_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS requested_date date,
  ADD COLUMN IF NOT EXISTS requested_time text,
  ADD COLUMN IF NOT EXISTS message text;

ALTER TABLE maintenance_requests
  ADD COLUMN IF NOT EXISTS property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS lease_id uuid REFERENCES leases(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS landlord_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS category text,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS photos text[] NOT NULL DEFAULT '{}';

-- status / priority : créées en texte si elles n'existent pas ; si ce sont
-- déjà des enums, on y ajoute les valeurs utilisées par l'app.
ALTER TABLE visit_requests ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'en_attente';
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'ouvert';
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'normale';

DO $$
DECLARE v text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'visit_status') THEN
    FOREACH v IN ARRAY ARRAY['en_attente', 'confirmee', 'refusee'] LOOP
      EXECUTE format('ALTER TYPE visit_status ADD VALUE IF NOT EXISTS %L', v);
    END LOOP;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'maintenance_status') THEN
    FOREACH v IN ARRAY ARRAY['ouvert', 'en_cours', 'resolu'] LOOP
      EXECUTE format('ALTER TYPE maintenance_status ADD VALUE IF NOT EXISTS %L', v);
    END LOOP;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'maintenance_priority') THEN
    FOREACH v IN ARRAY ARRAY['normale', 'urgente', 'critique'] LOOP
      EXECUTE format('ALTER TYPE maintenance_priority ADD VALUE IF NOT EXISTS %L', v);
    END LOOP;
  END IF;
END $$;

-- ─── RLS ─────────────────────────────────────────────────────────────────────
ALTER TABLE visit_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Visites visibles par les parties" ON visit_requests;
DROP POLICY IF EXISTS "Locataire demande une visite" ON visit_requests;
DROP POLICY IF EXISTS "Parties modifient la visite" ON visit_requests;
CREATE POLICY "Visites visibles par les parties" ON visit_requests
  FOR SELECT TO authenticated
  USING (tenant_id = auth.uid() OR landlord_id = auth.uid());
CREATE POLICY "Locataire demande une visite" ON visit_requests
  FOR INSERT TO authenticated WITH CHECK (tenant_id = auth.uid());
CREATE POLICY "Parties modifient la visite" ON visit_requests
  FOR UPDATE TO authenticated
  USING (tenant_id = auth.uid() OR landlord_id = auth.uid());

DROP POLICY IF EXISTS "Maintenance visible par les parties" ON maintenance_requests;
DROP POLICY IF EXISTS "Locataire signale un problème" ON maintenance_requests;
DROP POLICY IF EXISTS "Parties modifient la maintenance" ON maintenance_requests;
CREATE POLICY "Maintenance visible par les parties" ON maintenance_requests
  FOR SELECT TO authenticated
  USING (tenant_id = auth.uid() OR landlord_id = auth.uid());
CREATE POLICY "Locataire signale un problème" ON maintenance_requests
  FOR INSERT TO authenticated WITH CHECK (tenant_id = auth.uid());
CREATE POLICY "Parties modifient la maintenance" ON maintenance_requests
  FOR UPDATE TO authenticated
  USING (tenant_id = auth.uid() OR landlord_id = auth.uid());

-- ─── Photos de maintenance (bucket public, comme les images de biens) ────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('maintenance-photos', 'maintenance-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Maintenance photos lecture" ON storage.objects;
DROP POLICY IF EXISTS "Maintenance photos envoi" ON storage.objects;
CREATE POLICY "Maintenance photos lecture" ON storage.objects
  FOR SELECT USING (bucket_id = 'maintenance-photos');
CREATE POLICY "Maintenance photos envoi" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'maintenance-photos'
              AND (storage.foldername(name))[1] = auth.uid()::text);
