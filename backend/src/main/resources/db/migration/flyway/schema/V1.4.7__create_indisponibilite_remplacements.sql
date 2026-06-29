-- Trace les assignations de programme impactées par une indisponibilité,
-- afin de pouvoir rétablir exactement le chauffeur titulaire à la fin.
CREATE TABLE IF NOT EXISTS indisponibilite_remplacements (
    id                       BIGSERIAL PRIMARY KEY,
    indisponibilite_id       BIGINT NOT NULL,
    programme_chauffeur_id   BIGINT NOT NULL,
    chauffeur_titulaire_id   BIGINT NOT NULL,
    created_at               TIMESTAMP,
    updated_at               TIMESTAMP,
    CONSTRAINT fk_ir_indispo
        FOREIGN KEY (indisponibilite_id) REFERENCES indisponibilites(id) ON DELETE CASCADE,
    CONSTRAINT fk_ir_programme_chauffeur
        FOREIGN KEY (programme_chauffeur_id) REFERENCES vehicule_programme_chauffeurs(id),
    CONSTRAINT fk_ir_titulaire
        FOREIGN KEY (chauffeur_titulaire_id) REFERENCES chauffeurs(id)
);

CREATE INDEX IF NOT EXISTS idx_ir_indispo
    ON indisponibilite_remplacements(indisponibilite_id);
