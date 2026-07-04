-- Historique des statuts de véhicule : une ligne par période passée dans un
-- statut (date_fin NULL = période en cours). Alimentée à chaque transition
-- effective (recalcul automatique ou décision manuelle), jamais reconstituable
-- rétroactivement — d'où le seed initial avec le statut courant du parc.
-- Sert aux KPI temporels de l'état de parc : ancienneté dans le statut,
-- durée moyenne d'immobilisation, coût d'immobilisation.
CREATE TABLE IF NOT EXISTS vehicule_statut_historique (
    id          BIGSERIAL   PRIMARY KEY,
    vehicule_id BIGINT      NOT NULL REFERENCES vehicules (id) ON DELETE CASCADE,
    statut      VARCHAR(30) NOT NULL,
    motif       VARCHAR(40),
    date_debut  TIMESTAMP   NOT NULL DEFAULT NOW(),
    date_fin    TIMESTAMP,
    created_at  TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- Accès direct à la période en cours d'un véhicule (au plus une par véhicule).
CREATE UNIQUE INDEX IF NOT EXISTS idx_vehicule_statut_historique_en_cours
    ON vehicule_statut_historique (vehicule_id)
    WHERE date_fin IS NULL;

CREATE INDEX IF NOT EXISTS idx_vehicule_statut_historique_vehicule
    ON vehicule_statut_historique (vehicule_id, date_debut);

-- Seed : ouvre une période avec le statut courant de chaque véhicule.
INSERT INTO vehicule_statut_historique (vehicule_id, statut, date_debut)
SELECT id, statut, NOW()
FROM vehicules
WHERE statut IS NOT NULL;
