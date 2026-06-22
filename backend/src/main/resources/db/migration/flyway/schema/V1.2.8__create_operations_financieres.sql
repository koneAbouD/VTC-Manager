CREATE TABLE IF NOT EXISTS operations_financieres (
    id                    BIGSERIAL      PRIMARY KEY,
    reference             VARCHAR(30)    NOT NULL,
    type_operation        VARCHAR(20)    NOT NULL,
    categorie_id          BIGINT,
    sous_categorie_id     BIGINT,
    chauffeur_id          BIGINT,
    vehicule_id           BIGINT,
    montant               NUMERIC(19, 2) NOT NULL,
    mode_paiement         VARCHAR(20),
    date_operation        DATE           NOT NULL,
    commentaire           TEXT,
    statut                VARCHAR(20)    NOT NULL,
    detail_maintenance_id BIGINT,
    created_at            TIMESTAMP,
    updated_at            TIMESTAMP,
    CONSTRAINT uk_operations_financieres_reference       UNIQUE (reference),
    CONSTRAINT uk_operations_financieres_detail_maint    UNIQUE (detail_maintenance_id),
    CONSTRAINT fk_operations_financieres_categorie       FOREIGN KEY (categorie_id)          REFERENCES categories_operation(id),
    CONSTRAINT fk_operations_financieres_sous_categorie  FOREIGN KEY (sous_categorie_id)     REFERENCES sous_categories_operation(id),
    CONSTRAINT fk_operations_financieres_chauffeur       FOREIGN KEY (chauffeur_id)          REFERENCES chauffeurs(id),
    CONSTRAINT fk_operations_financieres_vehicule        FOREIGN KEY (vehicule_id)           REFERENCES vehicules(id),
    CONSTRAINT fk_operations_financieres_detail_maint    FOREIGN KEY (detail_maintenance_id) REFERENCES details_maintenance(id),
    CONSTRAINT chk_operations_financieres_type           CHECK (type_operation IN ('REVENU', 'DEPENSE')),
    CONSTRAINT chk_operations_financieres_statut         CHECK (statut IN ('BROUILLON', 'VALIDEE', 'ANNULEE'))
);

CREATE INDEX IF NOT EXISTS idx_operations_financieres_type         ON operations_financieres(type_operation);
CREATE INDEX IF NOT EXISTS idx_operations_financieres_chauffeur    ON operations_financieres(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_operations_financieres_vehicule     ON operations_financieres(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_operations_financieres_date         ON operations_financieres(date_operation);
CREATE INDEX IF NOT EXISTS idx_operations_financieres_statut       ON operations_financieres(statut);
