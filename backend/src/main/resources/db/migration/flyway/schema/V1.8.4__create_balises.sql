-- Référentiel des balises GPS installées sur les véhicules.
CREATE TABLE IF NOT EXISTS balises (
    id               BIGSERIAL PRIMARY KEY,
    identifiant      VARCHAR(100) NOT NULL UNIQUE,
    numero_telephone VARCHAR(30),
    actif            BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW()
);
