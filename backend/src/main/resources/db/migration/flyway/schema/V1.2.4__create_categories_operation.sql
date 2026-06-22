CREATE TABLE IF NOT EXISTS categories_operation (
    id             BIGSERIAL   PRIMARY KEY,
    code           VARCHAR(50) NOT NULL,
    libelle        VARCHAR(255) NOT NULL,
    type_operation VARCHAR(20) NOT NULL,
    actif          BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP,
    updated_at     TIMESTAMP,
    CONSTRAINT uk_categories_operation_code        UNIQUE (code),
    CONSTRAINT chk_categories_operation_type       CHECK (type_operation IN ('REVENU', 'DEPENSE'))
);

CREATE INDEX IF NOT EXISTS idx_categories_operation_type ON categories_operation(type_operation);
