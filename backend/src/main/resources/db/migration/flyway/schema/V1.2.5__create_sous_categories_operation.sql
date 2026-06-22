CREATE TABLE IF NOT EXISTS sous_categories_operation (
    id           BIGSERIAL    PRIMARY KEY,
    code         VARCHAR(50)  NOT NULL,
    libelle      VARCHAR(255) NOT NULL,
    categorie_id BIGINT       NOT NULL,
    actif        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP,
    CONSTRAINT uk_sous_categories_operation_code      UNIQUE (code),
    CONSTRAINT uk_sous_categories_operation_categorie UNIQUE (categorie_id),
    CONSTRAINT fk_sous_categories_operation_categorie FOREIGN KEY (categorie_id) REFERENCES categories_operation(id)
);
