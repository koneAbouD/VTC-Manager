CREATE TABLE IF NOT EXISTS types_activite (
    id          BIGSERIAL PRIMARY KEY,
    nom         VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);
