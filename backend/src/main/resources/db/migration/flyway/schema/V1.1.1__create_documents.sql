CREATE TABLE IF NOT EXISTS documents (
    id               BIGSERIAL PRIMARY KEY,
    type_document_id BIGINT      NOT NULL,
    reference        VARCHAR(255),
    date_emission    DATE,
    date_expiration  DATE,
    statut           VARCHAR(20) NOT NULL,
    fichier_url      VARCHAR(255),
    fichier_nom      VARCHAR(255),
    fichier_type     VARCHAR(255),
    cible            VARCHAR(15) NOT NULL,
    cible_id         BIGINT      NOT NULL,
    date_archivage   DATE,
    archived_by      VARCHAR(255),
    raison_archivage VARCHAR(255),
    permanence       BOOLEAN,
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    CONSTRAINT fk_documents_type_document FOREIGN KEY (type_document_id) REFERENCES types_document(id),
    CONSTRAINT chk_documents_cible        CHECK (cible IN ('VEHICULE', 'CHAUFFEUR'))
);

CREATE INDEX IF NOT EXISTS idx_documents_type_document ON documents(type_document_id);
CREATE INDEX IF NOT EXISTS idx_documents_cible_id      ON documents(cible, cible_id);
CREATE INDEX IF NOT EXISTS idx_documents_statut        ON documents(statut);
CREATE INDEX IF NOT EXISTS idx_documents_date_expir    ON documents(date_expiration);
