CREATE TABLE IF NOT EXISTS encaissements_penalite (
    id                      BIGSERIAL      PRIMARY KEY,
    ligne_penalite_id       BIGINT         NOT NULL,
    operation_financiere_id BIGINT,
    montant                 NUMERIC(19, 2) NOT NULL,
    mode_encaissement       VARCHAR(20)    NOT NULL,
    date_encaissement       DATE           NOT NULL,
    reference               VARCHAR(100),
    commentaire             TEXT,
    created_at              TIMESTAMP,
    updated_at              TIMESTAMP,
    CONSTRAINT fk_ep_ligne     FOREIGN KEY (ligne_penalite_id)       REFERENCES lignes_penalite(id),
    CONSTRAINT fk_ep_operation FOREIGN KEY (operation_financiere_id) REFERENCES operations_financieres(id),
    CONSTRAINT chk_ep_mode     CHECK (mode_encaissement IN ('ESPECES', 'MOBILE_MONEY')),
    CONSTRAINT chk_ep_montant  CHECK (montant > 0)
);

CREATE INDEX IF NOT EXISTS idx_ep_ligne ON encaissements_penalite(ligne_penalite_id);
CREATE INDEX IF NOT EXISTS idx_ep_date  ON encaissements_penalite(date_encaissement);
