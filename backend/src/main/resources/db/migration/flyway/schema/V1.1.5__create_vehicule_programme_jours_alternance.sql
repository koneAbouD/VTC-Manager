CREATE TABLE IF NOT EXISTS vehicule_programme_jours_alternance (
    programme_id BIGINT     NOT NULL,
    jour_semaine VARCHAR(15),
    CONSTRAINT fk_vp_jours_alternance_programme FOREIGN KEY (programme_id) REFERENCES vehicule_programmes(id)
);

CREATE INDEX IF NOT EXISTS idx_vp_jours_alternance_programme ON vehicule_programme_jours_alternance(programme_id);
