CREATE TABLE IF NOT EXISTS lignes_cotisation (
    id               BIGSERIAL      PRIMARY KEY,
    vehicule_id      BIGINT         NOT NULL,
    chauffeur_id     BIGINT         NOT NULL,
    date_cotisation  DATE           NOT NULL,
    nom_cotisation   VARCHAR(100)   NOT NULL,
    montant_du       NUMERIC(19, 2) NOT NULL,
    montant_encaisse NUMERIC(19, 2) NOT NULL DEFAULT 0,
    statut           VARCHAR(30)    NOT NULL DEFAULT 'EN_ATTENTE',
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    CONSTRAINT uk_lignes_cotisation_vehicule_chauffeur_date_nom UNIQUE (vehicule_id, chauffeur_id, date_cotisation, nom_cotisation),
    CONSTRAINT fk_lignes_cotisation_vehicule   FOREIGN KEY (vehicule_id)  REFERENCES vehicules(id),
    CONSTRAINT fk_lignes_cotisation_chauffeur  FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id),
    CONSTRAINT chk_lignes_cotisation_statut    CHECK (statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE', 'ENCAISSE', 'ANNULEE')),
    CONSTRAINT chk_lignes_cotisation_montant   CHECK (montant_encaisse >= 0)
);

CREATE INDEX IF NOT EXISTS idx_lignes_cotisation_vehicule  ON lignes_cotisation(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_lignes_cotisation_chauffeur ON lignes_cotisation(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_lignes_cotisation_date      ON lignes_cotisation(date_cotisation);
CREATE INDEX IF NOT EXISTS idx_lignes_cotisation_statut    ON lignes_cotisation(statut);
