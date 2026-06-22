CREATE TABLE IF NOT EXISTS modeles (
    id         BIGSERIAL PRIMARY KEY,
    nom        VARCHAR(255) NOT NULL,
    type_id    BIGINT       NOT NULL,
    marque_id  BIGINT       NOT NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_modeles_type            FOREIGN KEY (type_id)   REFERENCES types_vehicule(id),
    CONSTRAINT fk_modeles_marque          FOREIGN KEY (marque_id) REFERENCES marques(id),
    CONSTRAINT uk_modeles_nom_type_marque UNIQUE (nom, type_id, marque_id)
);

CREATE INDEX IF NOT EXISTS idx_modeles_type   ON modeles(type_id);
CREATE INDEX IF NOT EXISTS idx_modeles_marque ON modeles(marque_id);
