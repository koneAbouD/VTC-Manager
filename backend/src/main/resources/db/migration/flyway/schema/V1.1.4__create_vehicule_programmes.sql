CREATE TABLE IF NOT EXISTS vehicule_programmes (
    id                          BIGSERIAL    PRIMARY KEY,
    vehicule_id                 BIGINT       NOT NULL,
    nombre_chauffeurs_autorises INT          NOT NULL,
    type_programme              VARCHAR(30)  NOT NULL,
    heure_debut_service         TIME         NOT NULL,
    heure_fin_service           TIME         NOT NULL,
    mode_alternance             VARCHAR(30)  NOT NULL,
    jours_alternance            INT,
    date_debut_alternance       DATE,
    jour_salaire_actif          BOOLEAN      NOT NULL DEFAULT FALSE,
    jour_salaire                VARCHAR(15),
    created_at                  TIMESTAMP,
    updated_at                  TIMESTAMP,
    CONSTRAINT uk_vehicule_programmes_vehicule  UNIQUE (vehicule_id),
    CONSTRAINT fk_vehicule_programmes_vehicule  FOREIGN KEY (vehicule_id) REFERENCES vehicules(id)
);
