CREATE TABLE IF NOT EXISTS contraventions (
    id               BIGSERIAL      PRIMARY KEY,
    date_infraction  DATE           NOT NULL,
    type_infraction  VARCHAR(255),
    lieu             VARCHAR(255),
    description      TEXT,
    montant          NUMERIC(19, 2),
    cotisation       NUMERIC(19, 2),
    montant_paye     NUMERIC(19, 2),
    statut           VARCHAR(30),
    date_paiement    DATE,
    chauffeur_id     BIGINT,
    vehicule_id      BIGINT,
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    CONSTRAINT fk_contraventions_chauffeur FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id),
    CONSTRAINT fk_contraventions_vehicule  FOREIGN KEY (vehicule_id)  REFERENCES vehicules(id)
);

CREATE INDEX IF NOT EXISTS idx_contraventions_chauffeur ON contraventions(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_contraventions_vehicule  ON contraventions(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_contraventions_statut    ON contraventions(statut);
