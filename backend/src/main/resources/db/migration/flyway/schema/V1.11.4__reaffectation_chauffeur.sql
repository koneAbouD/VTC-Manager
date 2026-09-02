-- Réaffectation du chauffeur d'une créance (recette ou cotisation).
--
-- Changer le chauffeur d'une ligne ne déplace aucun montant : le véhicule reste
-- l'axe de résultat, seul l'axe de tiers bouge. C'est ce qui rend l'opération
-- possible même après encaissement — là où corriger un montant ne l'est pas —
-- et impossible dès qu'un arrêté de compte a consigné la créance au nom de
-- quelqu'un.
--
-- La trace est indispensable : six mois plus tard, une recette portée par un
-- chauffeur que le programme du jour ne désignait pas est inexplicable sans
-- elle. Une table plutôt que des colonnes sur la ligne : une même ligne peut
-- être réaffectée deux fois, et l'historique doit garder les deux.

CREATE TABLE IF NOT EXISTS reaffectations_chauffeur (
    id                   BIGSERIAL    PRIMARY KEY,
    document_type        VARCHAR(20)  NOT NULL,          -- RECETTE | COTISATION
    document_id          BIGINT       NOT NULL,
    vehicule_id          BIGINT,
    date_document        DATE,
    ancien_chauffeur_id  BIGINT       NOT NULL,
    nouveau_chauffeur_id BIGINT       NOT NULL,
    motif                TEXT         NOT NULL,
    -- Ce que la réaffectation a entraîné dans son sillage : écritures
    -- d'encaissement suivies, pénalités basculées. Consigné plutôt que
    -- recalculé — l'état d'aujourd'hui ne dit plus ce qui a bougé ce jour-là.
    operations_reprises  INTEGER      NOT NULL DEFAULT 0,
    penalites_reprises   INTEGER      NOT NULL DEFAULT 0,
    created_by           VARCHAR(255),
    created_at           TIMESTAMP,
    updated_at           TIMESTAMP,
    CONSTRAINT chk_reaffectations_document   CHECK (document_type IN ('RECETTE', 'COTISATION')),
    CONSTRAINT chk_reaffectations_chauffeurs CHECK (ancien_chauffeur_id <> nouveau_chauffeur_id),
    CONSTRAINT fk_reaffectations_ancien      FOREIGN KEY (ancien_chauffeur_id)  REFERENCES chauffeurs(id),
    CONSTRAINT fk_reaffectations_nouveau     FOREIGN KEY (nouveau_chauffeur_id) REFERENCES chauffeurs(id),
    CONSTRAINT fk_reaffectations_vehicule    FOREIGN KEY (vehicule_id)          REFERENCES vehicules(id)
);

-- L'historique se lit par document (fiche de la ligne) ou par chauffeur
-- (« qu'a-t-on retiré du compte de ce chauffeur ? »).
CREATE INDEX IF NOT EXISTS idx_reaffectations_document
    ON reaffectations_chauffeur(document_type, document_id);
CREATE INDEX IF NOT EXISTS idx_reaffectations_ancien
    ON reaffectations_chauffeur(ancien_chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_reaffectations_nouveau
    ON reaffectations_chauffeur(nouveau_chauffeur_id);
