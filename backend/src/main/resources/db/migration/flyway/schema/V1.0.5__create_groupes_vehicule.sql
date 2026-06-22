CREATE TABLE IF NOT EXISTS groupes_vehicule (
    id               BIGSERIAL PRIMARY KEY,
    nom              VARCHAR(255) NOT NULL UNIQUE,
    description      TEXT,
    type_activite_id BIGINT,
    statut           VARCHAR(20)  NOT NULL DEFAULT 'ACTIF',
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by       VARCHAR(255),
    updated_by       VARCHAR(255),
    CONSTRAINT fk_groupes_vehicule_type_activite FOREIGN KEY (type_activite_id) REFERENCES types_activite(id),
    CONSTRAINT chk_groupes_vehicule_statut       CHECK (statut IN ('ACTIF', 'INACTIF', 'SUSPENDU'))
);

CREATE INDEX IF NOT EXISTS idx_groupes_vehicule_nom ON groupes_vehicule(nom);
