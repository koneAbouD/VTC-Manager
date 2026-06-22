CREATE TABLE IF NOT EXISTS vehicule_programme_chauffeurs (
    id                  BIGSERIAL PRIMARY KEY,
    programme_id        BIGINT    NOT NULL,
    chauffeur_id        BIGINT    NOT NULL,
    ordre_alternance    INT,
    ordre_jour_salaire  INT,
    date_service        DATE,
    created_at          TIMESTAMP,
    updated_at          TIMESTAMP,
    CONSTRAINT fk_vpc_programme  FOREIGN KEY (programme_id) REFERENCES vehicule_programmes(id),
    CONSTRAINT fk_vpc_chauffeur  FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id)
);

CREATE INDEX IF NOT EXISTS idx_vpc_programme  ON vehicule_programme_chauffeurs(programme_id);
CREATE INDEX IF NOT EXISTS idx_vpc_chauffeur  ON vehicule_programme_chauffeurs(chauffeur_id);
