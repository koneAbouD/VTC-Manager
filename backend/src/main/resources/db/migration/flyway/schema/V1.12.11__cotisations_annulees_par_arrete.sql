-- Un arrêté de compte abandonne désormais les cotisations encore ouvertes de sa
-- période (en attente, ou partiellement encaissées sans fonds restant à rendre) :
-- le compte est arrêté, ce reste ne sera plus réclamé.
--
-- La colonne dit quel arrêté les a annulées. Sans elle, l'annulation de
-- l'arrêté ne saurait distinguer ces lignes de celles annulées à la main, et
-- ne pourrait ni les rouvrir, ni laisser les autres annulées.
ALTER TABLE lignes_cotisation
    ADD COLUMN IF NOT EXISTS annulee_par_arrete_id BIGINT
        REFERENCES arretes_compte(id);

CREATE INDEX IF NOT EXISTS idx_lignes_cotisation_annulee_par_arrete
    ON lignes_cotisation(annulee_par_arrete_id) WHERE annulee_par_arrete_id IS NOT NULL;
