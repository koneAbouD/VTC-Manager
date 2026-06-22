CREATE TABLE IF NOT EXISTS catalogue_elements_maintenance (
    id         BIGSERIAL    PRIMARY KEY,
    libelle    VARCHAR(255) NOT NULL,
    actif      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT uk_catalogue_elements_maintenance_libelle UNIQUE (libelle)
);
