CREATE TABLE IF NOT EXISTS vehicule_photos (
    id          BIGSERIAL    PRIMARY KEY,
    vehicule_id BIGINT       NOT NULL,
    object_name VARCHAR(255) NOT NULL,
    ordre       INT,
    CONSTRAINT fk_vehicule_photos_vehicule FOREIGN KEY (vehicule_id) REFERENCES vehicules(id)
);

CREATE INDEX IF NOT EXISTS idx_vehicule_photos_vehicule ON vehicule_photos(vehicule_id);
