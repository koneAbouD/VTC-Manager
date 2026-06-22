CREATE TABLE IF NOT EXISTS encaissements (
    id                      BIGSERIAL      PRIMARY KEY,
    ligne_recette_id        BIGINT         NOT NULL,
    operation_financiere_id BIGINT,
    montant                 NUMERIC(19, 2) NOT NULL,
    mode_encaissement       VARCHAR(20)    NOT NULL,
    date_encaissement       DATE           NOT NULL,
    reference               VARCHAR(100),
    commentaire             TEXT,
    created_at              TIMESTAMP,
    updated_at              TIMESTAMP,
    CONSTRAINT fk_encaissements_ligne_recette       FOREIGN KEY (ligne_recette_id)        REFERENCES lignes_recette(id),
    CONSTRAINT fk_encaissements_operation           FOREIGN KEY (operation_financiere_id) REFERENCES operations_financieres(id),
    CONSTRAINT chk_encaissements_mode               CHECK (mode_encaissement IN ('ESPECES', 'MOBILE_MONEY')),
    CONSTRAINT chk_encaissements_montant            CHECK (montant > 0)
);

CREATE INDEX IF NOT EXISTS idx_encaissements_ligne_recette ON encaissements(ligne_recette_id);
CREATE INDEX IF NOT EXISTS idx_encaissements_date          ON encaissements(date_encaissement);
