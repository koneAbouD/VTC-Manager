CREATE TABLE IF NOT EXISTS cotisation_template (
    id                   BIGSERIAL PRIMARY KEY,
    nom                  VARCHAR(255),
    montant              NUMERIC(15, 2),
    condition_travail_id BIGINT NOT NULL,
    created_at           TIMESTAMP,
    updated_at           TIMESTAMP,
    CONSTRAINT fk_cotisation_template_condition_travail FOREIGN KEY (condition_travail_id) REFERENCES condition_travail(id)
);

CREATE INDEX IF NOT EXISTS idx_cotisation_template_condition_travail ON cotisation_template(condition_travail_id);
