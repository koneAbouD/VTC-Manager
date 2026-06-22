CREATE TABLE IF NOT EXISTS encaissements_cotisation (
    id                      BIGSERIAL      PRIMARY KEY,
    ligne_cotisation_id     BIGINT         NOT NULL,
    operation_financiere_id BIGINT,
    montant                 NUMERIC(19, 2) NOT NULL,
    mode_encaissement       VARCHAR(20)    NOT NULL,
    date_encaissement       DATE           NOT NULL,
    reference               VARCHAR(100),
    commentaire             TEXT,
    created_at              TIMESTAMP,
    updated_at              TIMESTAMP,
    CONSTRAINT fk_encaissements_cotisation_ligne      FOREIGN KEY (ligne_cotisation_id)     REFERENCES lignes_cotisation(id),
    CONSTRAINT fk_encaissements_cotisation_operation  FOREIGN KEY (operation_financiere_id) REFERENCES operations_financieres(id),
    CONSTRAINT chk_encaissements_cotisation_mode      CHECK (mode_encaissement IN ('ESPECES', 'MOBILE_MONEY')),
    CONSTRAINT chk_encaissements_cotisation_montant   CHECK (montant > 0)
);

CREATE INDEX IF NOT EXISTS idx_encaissements_cotisation_ligne ON encaissements_cotisation(ligne_cotisation_id);
CREATE INDEX IF NOT EXISTS idx_encaissements_cotisation_date  ON encaissements_cotisation(date_encaissement);
