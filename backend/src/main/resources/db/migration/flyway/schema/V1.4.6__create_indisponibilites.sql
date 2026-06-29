CREATE TABLE IF NOT EXISTS indisponibilites (
    id                       BIGSERIAL    PRIMARY KEY,
    chauffeur_id             BIGINT       NOT NULL,
    chauffeur_remplacant_id  BIGINT,
    date_debut               DATE         NOT NULL,
    date_fin                 DATE,
    motif                    VARCHAR(255),
    commentaire              TEXT,
    statut                   VARCHAR(30),
    created_at               TIMESTAMP,
    updated_at               TIMESTAMP,
    CONSTRAINT fk_indisponibilites_chauffeur
        FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id),
    CONSTRAINT fk_indisponibilites_remplacant
        FOREIGN KEY (chauffeur_remplacant_id) REFERENCES chauffeurs(id)
);

CREATE INDEX IF NOT EXISTS idx_indisponibilites_chauffeur  ON indisponibilites(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_indisponibilites_remplacant ON indisponibilites(chauffeur_remplacant_id);
CREATE INDEX IF NOT EXISTS idx_indisponibilites_statut     ON indisponibilites(statut);
