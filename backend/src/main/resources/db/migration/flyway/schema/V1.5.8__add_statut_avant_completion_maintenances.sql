-- Mémorise le statut d'une maintenance juste avant sa complétion (PLANIFIEE ou
-- EN_COURS). Permet, à l'annulation de l'opération de dépense générée, de
-- restaurer la maintenance à son statut exact d'origine (et non un statut figé).
ALTER TABLE maintenances
    ADD COLUMN IF NOT EXISTS statut_avant_completion VARCHAR(30);
