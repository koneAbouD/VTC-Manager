CREATE TABLE IF NOT EXISTS maintenances (
    id                    BIGSERIAL      PRIMARY KEY,
    type                  VARCHAR(40),
    date_prevue           DATE,
    date_effectuee        DATE,
    description           TEXT,
    kilometrage_au_moment INT,
    kilometrage_prochaine INT,
    cout                  NUMERIC(19, 2),
    prestataire           VARCHAR(255),
    statut                VARCHAR(30),
    vehicule_id           BIGINT,
    created_at            TIMESTAMP,
    updated_at            TIMESTAMP,
    CONSTRAINT fk_maintenances_vehicule FOREIGN KEY (vehicule_id) REFERENCES vehicules(id)
);

CREATE INDEX IF NOT EXISTS idx_maintenances_vehicule ON maintenances(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_maintenances_statut   ON maintenances(statut);
