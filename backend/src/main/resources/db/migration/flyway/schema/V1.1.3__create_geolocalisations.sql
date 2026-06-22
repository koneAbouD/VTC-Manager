CREATE TABLE IF NOT EXISTS geolocalisations (
    id          BIGSERIAL        PRIMARY KEY,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    horodatage  TIMESTAMP        NOT NULL,
    chauffeur_id BIGINT          NOT NULL,
    CONSTRAINT uk_geolocalisations_chauffeur  UNIQUE (chauffeur_id),
    CONSTRAINT fk_geolocalisations_chauffeur  FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id)
);
