-- ─────────────────────────────────────────────────────────────────────────────
-- Simplification des modes de paiement → ESPECES | MOBILE_MONEY
--   VIREMENT, CARTE, CHEQUE, PLATEFORME  →  MOBILE_MONEY
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE operations_financieres
SET mode_paiement = 'MOBILE_MONEY'
WHERE mode_paiement IN ('VIREMENT', 'CARTE', 'CHEQUE', 'PLATEFORME');

ALTER TABLE operations_financieres
    ADD CONSTRAINT chk_operations_financieres_mode_paiement
    CHECK (mode_paiement IS NULL OR mode_paiement IN ('ESPECES', 'MOBILE_MONEY'));
