CREATE TABLE IF NOT EXISTS document_categories (
    document_id BIGINT     NOT NULL,
    categorie   VARCHAR(5),
    CONSTRAINT fk_document_categories_document FOREIGN KEY (document_id) REFERENCES documents(id)
);

CREATE INDEX IF NOT EXISTS idx_document_categories_document ON document_categories(document_id);
