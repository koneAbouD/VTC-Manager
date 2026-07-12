-- Restitution des cotisations : une ligne de cotisation prise en compte dans un
-- arrêté de compte passe en RESTITUEE (dépôt rendu / netté), et n'est plus ni
-- active ni comptée dans le fonds restituable. La colonne arrete_id trace
-- l'arrêté qui l'a soldée.
ALTER TABLE lignes_cotisation
    DROP CONSTRAINT IF EXISTS chk_lignes_cotisation_statut;

ALTER TABLE lignes_cotisation
    ADD CONSTRAINT chk_lignes_cotisation_statut
        CHECK (statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE', 'ENCAISSE', 'ANNULEE', 'RESTITUEE'));

ALTER TABLE lignes_cotisation
    ADD COLUMN IF NOT EXISTS arrete_id BIGINT;

CREATE INDEX IF NOT EXISTS idx_lignes_cotisation_arrete ON lignes_cotisation(arrete_id);
