CREATE TABLE IF NOT EXISTS chauffeurs (
    id            BIGSERIAL PRIMARY KEY,
    nom           VARCHAR(255) NOT NULL,
    prenom        VARCHAR(255) NOT NULL,
    genre         VARCHAR(10),
    type          VARCHAR(15),
    date_naissance DATE,
    photo_url     VARCHAR(255),
    telephone     VARCHAR(255),
    email         VARCHAR(255),
    adresse       VARCHAR(255),
    statut        VARCHAR(30),
    date_embauche DATE,
    vehicule_id   BIGINT,
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP,
    CONSTRAINT fk_chauffeurs_vehicule FOREIGN KEY (vehicule_id) REFERENCES vehicules(id)
);

CREATE INDEX IF NOT EXISTS idx_chauffeurs_statut     ON chauffeurs(statut);
CREATE INDEX IF NOT EXISTS idx_chauffeurs_vehicule   ON chauffeurs(vehicule_id);
