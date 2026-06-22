CREATE TABLE IF NOT EXISTS lignes_recette (
    id               BIGSERIAL      PRIMARY KEY,
    vehicule_id      BIGINT         NOT NULL,
    chauffeur_id     BIGINT         NOT NULL,
    date_recette     DATE           NOT NULL,
    montant_attendu  NUMERIC(19, 2),
    montant_encaisse NUMERIC(19, 2) NOT NULL DEFAULT 0,
    statut           VARCHAR(30)    NOT NULL DEFAULT 'EN_ATTENTE',
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    CONSTRAINT uk_lignes_recette_vehicule_chauffeur_date UNIQUE (vehicule_id, chauffeur_id, date_recette),
    CONSTRAINT fk_lignes_recette_vehicule                FOREIGN KEY (vehicule_id)  REFERENCES vehicules(id),
    CONSTRAINT fk_lignes_recette_chauffeur               FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id),
    CONSTRAINT chk_lignes_recette_statut                 CHECK (statut IN ('EN_ATTENTE', 'PARTIELLEMENT_ENCAISSE', 'ENCAISSE', 'ANNULEE')),
    CONSTRAINT chk_lignes_recette_montant_encaisse       CHECK (montant_encaisse >= 0)
);

CREATE INDEX IF NOT EXISTS idx_lignes_recette_vehicule   ON lignes_recette(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_lignes_recette_chauffeur  ON lignes_recette(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_lignes_recette_date       ON lignes_recette(date_recette);
CREATE INDEX IF NOT EXISTS idx_lignes_recette_statut     ON lignes_recette(statut);
