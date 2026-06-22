CREATE TABLE IF NOT EXISTS gestionnaires_groupe (
    id          BIGSERIAL    PRIMARY KEY,
    groupe_id   BIGINT       NOT NULL,
    user_id     VARCHAR(255) NOT NULL,
    date_debut  DATE,
    date_fin    DATE,
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP,
    CONSTRAINT uk_gestionnaire_groupe_user  UNIQUE (groupe_id, user_id),
    CONSTRAINT fk_gestionnaires_groupe      FOREIGN KEY (groupe_id) REFERENCES groupes_vehicule(id)
);

CREATE INDEX IF NOT EXISTS idx_gestionnaires_groupe_groupe ON gestionnaires_groupe(groupe_id);
