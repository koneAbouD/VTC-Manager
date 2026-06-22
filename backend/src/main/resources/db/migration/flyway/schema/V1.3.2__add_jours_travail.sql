-- Jours de travail de la condition de travail (ex: LUNDI, MARDI...)
CREATE TABLE IF NOT EXISTS condition_travail_jours (
    condition_id BIGINT NOT NULL REFERENCES condition_travail(id) ON DELETE CASCADE,
    jour         VARCHAR(15) NOT NULL,
    PRIMARY KEY (condition_id, jour)
);

-- Jours de travail effectifs du programme véhicule
CREATE TABLE IF NOT EXISTS vehicule_programme_jours_travail (
    programme_id BIGINT NOT NULL REFERENCES vehicule_programmes(id) ON DELETE CASCADE,
    jour_semaine VARCHAR(15) NOT NULL,
    PRIMARY KEY (programme_id, jour_semaine)
);
