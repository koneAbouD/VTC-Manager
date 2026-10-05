-- Journal des corrections de montant dû : recette attendue, amende.
--
-- Changer ce qu'un chauffeur doit déplace sa créance, la balance âgée et le
-- résultat du véhicule. La ligne ne garde que la nouvelle valeur ; ce journal
-- dit qui l'a changée, quand, depuis quelle valeur et pourquoi.
CREATE TABLE IF NOT EXISTS modifications_montant (
    id               BIGSERIAL      PRIMARY KEY,
    document_type    VARCHAR(20)    NOT NULL,          -- RECETTE | PENALITE
    document_id      BIGINT         NOT NULL,
    ancien_montant   NUMERIC(19, 2) NOT NULL,
    nouveau_montant  NUMERIC(19, 2) NOT NULL,
    motif            VARCHAR(500)   NOT NULL,
    created_by       VARCHAR(255)   NOT NULL,
    created_at       TIMESTAMP      NOT NULL DEFAULT now(),
    CONSTRAINT chk_modifications_montant_document CHECK (document_type IN ('RECETTE', 'PENALITE'))
);

CREATE INDEX IF NOT EXISTS idx_modifications_montant_document
    ON modifications_montant(document_type, document_id);
