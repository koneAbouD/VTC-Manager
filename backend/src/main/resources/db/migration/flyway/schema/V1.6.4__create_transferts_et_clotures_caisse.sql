-- Transferts inter-comptes (dépôt d'espèces en banque, retrait mobile
-- money…) : ni revenu ni dépense, n'apparaît pas dans le compte de
-- résultat. Intégré au calcul des soldes (source en −, destination en +).
CREATE TABLE IF NOT EXISTS transferts_tresorerie (
    id                    BIGSERIAL      PRIMARY KEY,
    compte_source_id      BIGINT         NOT NULL REFERENCES comptes_tresorerie(id),
    compte_destination_id BIGINT         NOT NULL REFERENCES comptes_tresorerie(id),
    montant               NUMERIC(19, 2) NOT NULL,
    date_transfert        DATE           NOT NULL,
    commentaire           TEXT,
    created_at            TIMESTAMP,
    updated_at            TIMESTAMP,
    CONSTRAINT chk_transferts_montant  CHECK (montant > 0),
    CONSTRAINT chk_transferts_comptes  CHECK (compte_source_id <> compte_destination_id)
);

CREATE INDEX IF NOT EXISTS idx_transferts_source      ON transferts_tresorerie(compte_source_id);
CREATE INDEX IF NOT EXISTS idx_transferts_destination ON transferts_tresorerie(compte_destination_id);

-- Clôture de caisse : comptage physique vs solde théorique. L'écart éventuel
-- est tracé comme opération d'ajustement (motif obligatoire) : après
-- clôture, le solde du compte est aligné sur le comptage.
CREATE TABLE IF NOT EXISTS clotures_caisse (
    id              BIGSERIAL      PRIMARY KEY,
    compte_id       BIGINT         NOT NULL REFERENCES comptes_tresorerie(id),
    date_cloture    DATE           NOT NULL,
    solde_theorique NUMERIC(19, 2) NOT NULL,
    solde_compte    NUMERIC(19, 2) NOT NULL,
    ecart           NUMERIC(19, 2) NOT NULL,
    motif_ecart     TEXT,
    operation_id    BIGINT         REFERENCES operations_financieres(id),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    CONSTRAINT uk_clotures_caisse_compte_date UNIQUE (compte_id, date_cloture)
);

-- Catégories d'ajustement : un manque de caisse est une charge réelle,
-- un excédent un produit — ils participent au résultat.
INSERT INTO categories_operation (code, libelle, type_operation, actif, nature_resultat) VALUES
    ('ECART_CAISSE_MANQUANT', 'Manquant de caisse', 'DEPENSE', TRUE, 'CHARGE_FIXE'),
    ('ECART_CAISSE_EXCEDENT', 'Excédent de caisse', 'REVENU',  TRUE, 'PRODUIT_EXPLOITATION')
ON CONFLICT (code) DO NOTHING;
