CREATE TABLE IF NOT EXISTS marques (
    id           BIGSERIAL PRIMARY KEY,
    nom          VARCHAR(255) NOT NULL,
    type_id      BIGINT       NOT NULL,
    pays_origine VARCHAR(255),
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_marques_type     FOREIGN KEY (type_id) REFERENCES types_vehicule(id),
    CONSTRAINT uk_marques_nom_type UNIQUE (nom, type_id)
);

CREATE INDEX IF NOT EXISTS idx_marques_type ON marques(type_id);
