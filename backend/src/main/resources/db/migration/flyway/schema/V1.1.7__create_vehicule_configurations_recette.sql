CREATE TABLE IF NOT EXISTS vehicule_configurations_recette (
    id                             BIGSERIAL    PRIMARY KEY,
    vehicule_id                    BIGINT       NOT NULL,
    mode_encaissement              VARCHAR(30)  NOT NULL,
    type_recette                   VARCHAR(30)  NOT NULL,
    frequence_versement            VARCHAR(30)  NOT NULL,
    heure_limite_versement         TIME         NOT NULL,
    montant_objectif_par_chauffeur NUMERIC(19, 2),
    montant_jour_salaire           NUMERIC(19, 2),
    created_at                     TIMESTAMP,
    updated_at                     TIMESTAMP,
    CONSTRAINT uk_vehicule_configurations_recette_vehicule  UNIQUE (vehicule_id),
    CONSTRAINT fk_vehicule_configurations_recette_vehicule  FOREIGN KEY (vehicule_id) REFERENCES vehicules(id)
);
