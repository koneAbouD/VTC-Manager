-- Indisponibilité (immobilisation) d'un véhicule hors atelier : accident/sinistre,
-- panne en attente de pièces, immobilisation administrative ou juridique.
-- Pendant la période le véhicule est IMMOBILISE et ne génère ni recette,
-- ni cotisation, ni pénalité. Symétrique de la table `indisponibilites` (chauffeur).
CREATE TABLE IF NOT EXISTS indisponibilites_vehicule (
    id            BIGSERIAL    PRIMARY KEY,
    vehicule_id   BIGINT       NOT NULL,
    date_debut    DATE         NOT NULL,
    date_fin      DATE,
    motif         VARCHAR(255),
    commentaire   TEXT,
    statut        VARCHAR(30),
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP,
    CONSTRAINT fk_indisponibilites_vehicule_vehicule
        FOREIGN KEY (vehicule_id) REFERENCES vehicules(id)
);

CREATE INDEX IF NOT EXISTS idx_indisponibilites_vehicule_vehicule ON indisponibilites_vehicule(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_indisponibilites_vehicule_statut   ON indisponibilites_vehicule(statut);
