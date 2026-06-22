CREATE TABLE IF NOT EXISTS types_document (
    id          BIGSERIAL PRIMARY KEY,
    nom         VARCHAR(255) NOT NULL UNIQUE,
    cible       VARCHAR(20)  NOT NULL,
    obligatoire BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);
