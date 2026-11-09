-- 001 — Flux de location : demande de bail, acceptation, paiement
-- À exécuter dans Supabase > SQL Editor. Idempotent (peut être relancé).

-- Valeurs de statut utilisées par l'app
ALTER TYPE lease_status ADD VALUE IF NOT EXISTS 'en_attente';
ALTER TYPE lease_status ADD VALUE IF NOT EXISTS 'actif';
ALTER TYPE lease_status ADD VALUE IF NOT EXISTS 'resilie';

-- Colonnes utilisées par la demande de location
ALTER TABLE leases ADD COLUMN IF NOT EXISTS tenant_message text;
ALTER TABLE leases ADD COLUMN IF NOT EXISTS deposit_amount numeric;

-- ─── Leases ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Parties voient leurs baux" ON leases;
DROP POLICY IF EXISTS "Locataire crée un bail" ON leases;
DROP POLICY IF EXISTS "Parties modifient leur bail" ON leases;

CREATE POLICY "Parties voient leurs baux"
  ON leases FOR SELECT TO authenticated
  USING (tenant_id = auth.uid() OR landlord_id = auth.uid());

CREATE POLICY "Locataire crée un bail"
  ON leases FOR INSERT TO authenticated
  WITH CHECK (tenant_id = auth.uid());

CREATE POLICY "Parties modifient leur bail"
  ON leases FOR UPDATE TO authenticated
  USING (tenant_id = auth.uid() OR landlord_id = auth.uid());

-- ─── Payments ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Parties voient leurs paiements" ON payments;
DROP POLICY IF EXISTS "Locataire crée un paiement" ON payments;
DROP POLICY IF EXISTS "Système update les paiements" ON payments;

CREATE POLICY "Parties voient leurs paiements"
  ON payments FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM leases l
    WHERE l.id = payments.lease_id
      AND (l.tenant_id = auth.uid() OR l.landlord_id = auth.uid())));

CREATE POLICY "Locataire crée un paiement"
  ON payments FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM leases l
    WHERE l.id = payments.lease_id AND l.tenant_id = auth.uid()));

CREATE POLICY "Système update les paiements"
  ON payments FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM leases l
    WHERE l.id = payments.lease_id
      AND (l.tenant_id = auth.uid() OR l.landlord_id = auth.uid())));
