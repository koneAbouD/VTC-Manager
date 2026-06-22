CREATE TABLE IF NOT EXISTS vehicules (
    id                          BIGSERIAL PRIMARY KEY,
    immatriculation             VARCHAR(255) NOT NULL,
    type_activite_id            BIGINT,
    groupe_id                   BIGINT,
    condition_travail_id        BIGINT,
    type_vehicule_id            BIGINT,
    marque_id                   BIGINT       NOT NULL,
    modele_id                   BIGINT       NOT NULL,
    numero_chassis              VARCHAR(50),
    numero_telephone_vehicule   VARCHAR(30),
    numero_telephone_balise     VARCHAR(30),
    identifiant_balise          VARCHAR(100),
    couleur                     VARCHAR(255),
    kilometrage                 INT,
    statut                      VARCHAR(30),
    date_achat                  DATE,
    date_prochaine_maintenance  DATE,
    date_mise_en_circulation    DATE,
    date_entree_flotte          DATE,
    created_at                  TIMESTAMP,
    updated_at                  TIMESTAMP,
    CONSTRAINT uk_vehicules_immatriculation             UNIQUE (immatriculation),
    CONSTRAINT fk_vehicules_type_activite               FOREIGN KEY (type_activite_id)    REFERENCES types_activite(id),
    CONSTRAINT fk_vehicules_groupe                      FOREIGN KEY (groupe_id)           REFERENCES groupes_vehicule(id),
    CONSTRAINT fk_vehicules_condition_travail           FOREIGN KEY (condition_travail_id) REFERENCES condition_travail(id),
    CONSTRAINT fk_vehicules_type_vehicule               FOREIGN KEY (type_vehicule_id)    REFERENCES types_vehicule(id),
    CONSTRAINT fk_vehicules_marque                      FOREIGN KEY (marque_id)           REFERENCES marques(id),
    CONSTRAINT fk_vehicules_modele                      FOREIGN KEY (modele_id)           REFERENCES modeles(id)
);

CREATE INDEX IF NOT EXISTS idx_vehicules_immatriculation      ON vehicules(immatriculation);
CREATE INDEX IF NOT EXISTS idx_vehicules_statut               ON vehicules(statut);
CREATE INDEX IF NOT EXISTS idx_vehicules_groupe               ON vehicules(groupe_id);
CREATE INDEX IF NOT EXISTS idx_vehicules_type_activite        ON vehicules(type_activite_id);
CREATE INDEX IF NOT EXISTS idx_vehicules_condition_travail    ON vehicules(condition_travail_id);
CREATE INDEX IF NOT EXISTS idx_vehicules_marque               ON vehicules(marque_id);
CREATE INDEX IF NOT EXISTS idx_vehicules_modele               ON vehicules(modele_id);
