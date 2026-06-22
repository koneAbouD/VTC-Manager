CREATE TABLE IF NOT EXISTS details_maintenance (
    id                 BIGSERIAL PRIMARY KEY,
    duree_maintenance  INT,
    created_at         TIMESTAMP,
    updated_at         TIMESTAMP
);
