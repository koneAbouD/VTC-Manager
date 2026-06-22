CREATE TABLE IF NOT EXISTS penalite_template (
    id                            BIGSERIAL PRIMARY KEY,
    type_penalite                 VARCHAR(255),
    type_sanction                 VARCHAR(255),
    duree_sanction_secondes       INT,
    montant                       DOUBLE PRECISION,
    duree_immobilisation_minutes  INT,
    condition_travail_id          BIGINT NOT NULL,
    created_at                    TIMESTAMP,
    updated_at                    TIMESTAMP,
    CONSTRAINT fk_penalite_template_condition_travail FOREIGN KEY (condition_travail_id) REFERENCES condition_travail(id)
);

CREATE INDEX IF NOT EXISTS idx_penalite_template_condition_travail ON penalite_template(condition_travail_id);
