CREATE TABLE IF NOT EXISTS vehicule_configuration_recette_cotisations (
    id               BIGSERIAL      PRIMARY KEY,
    configuration_id BIGINT         NOT NULL,
    nom              VARCHAR(255)   NOT NULL,
    montant          NUMERIC(19, 2) NOT NULL,
    ordre            INT            NOT NULL,
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    CONSTRAINT fk_vcrc_configuration FOREIGN KEY (configuration_id) REFERENCES vehicule_configurations_recette(id)
);

CREATE INDEX IF NOT EXISTS idx_vcrc_configuration ON vehicule_configuration_recette_cotisations(configuration_id);
