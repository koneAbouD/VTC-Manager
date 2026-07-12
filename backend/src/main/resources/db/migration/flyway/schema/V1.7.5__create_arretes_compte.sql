-- Arrêté de compte chauffeur : compensation des dettes et créances réciproques.
-- L'entreprise détient un dépôt pour le chauffeur (cotisations encaissées) et le
-- chauffeur lui doit ses créances ouvertes (recettes, pénalités, contraventions).
-- À la demande, sur une période libre, on arrête le compte : le fonds compense les
-- créances par antériorité et le net positif est restitué (« prime »).
--
-- Le périmètre de calcul peut être un chauffeur OU un véhicule, mais le versement
-- se résout TOUJOURS par bénéficiaire chauffeur (un véhicule multi-chauffeur produit
-- plusieurs règlements) : l'argent ne traverse jamais deux tiers.

CREATE TABLE IF NOT EXISTS arretes_compte (
    id               BIGSERIAL     PRIMARY KEY,
    perimetre        VARCHAR(20)   NOT NULL,           -- CHAUFFEUR | VEHICULE
    perimetre_id     BIGINT        NOT NULL,           -- chauffeur_id ou vehicule_id selon perimetre
    periode_debut    DATE          NOT NULL,
    periode_fin      DATE          NOT NULL,
    date_arrete      DATE          NOT NULL,
    reference        VARCHAR(50)   NOT NULL,
    statut           VARCHAR(20)   NOT NULL DEFAULT 'VALIDE',
    motif_annulation VARCHAR(500),
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    CONSTRAINT chk_arretes_compte_perimetre CHECK (perimetre IN ('CHAUFFEUR', 'VEHICULE')),
    CONSTRAINT chk_arretes_compte_statut    CHECK (statut IN ('VALIDE', 'ANNULE')),
    CONSTRAINT chk_arretes_compte_periode   CHECK (periode_fin >= periode_debut)
);

CREATE INDEX IF NOT EXISTS idx_arretes_compte_perimetre ON arretes_compte(perimetre, perimetre_id);
CREATE INDEX IF NOT EXISTS idx_arretes_compte_date      ON arretes_compte(date_arrete);

-- Photo figée des documents pris en compte (cotisations au crédit, créances au débit).
-- Chaque ligne porte chauffeur_id ET vehicule_id → ventilation par l'un ou l'autre axe.
CREATE TABLE IF NOT EXISTS lignes_arrete (
    id             BIGSERIAL      PRIMARY KEY,
    arrete_id      BIGINT         NOT NULL,
    document_type  VARCHAR(20)    NOT NULL,            -- COTISATION | RECETTE | PENALITE | CONTRAVENTION
    document_id    BIGINT         NOT NULL,
    chauffeur_id   BIGINT         NOT NULL,
    vehicule_id    BIGINT,
    montant        NUMERIC(19, 2) NOT NULL,
    sens           VARCHAR(20)    NOT NULL,            -- CREDIT (dépôt) | DEBIT (créance)
    created_at     TIMESTAMP,
    CONSTRAINT fk_lignes_arrete_arrete FOREIGN KEY (arrete_id) REFERENCES arretes_compte(id),
    CONSTRAINT chk_lignes_arrete_sens  CHECK (sens IN ('CREDIT', 'DEBIT'))
);

CREATE INDEX IF NOT EXISTS idx_lignes_arrete_arrete    ON lignes_arrete(arrete_id);
CREATE INDEX IF NOT EXISTS idx_lignes_arrete_chauffeur ON lignes_arrete(chauffeur_id);

-- Un règlement par bénéficiaire chauffeur : le net effectivement versé (ou reporté).
CREATE TABLE IF NOT EXISTS reglements_arrete (
    id                          BIGSERIAL      PRIMARY KEY,
    arrete_id                   BIGINT         NOT NULL,
    chauffeur_id                BIGINT         NOT NULL,
    total_cotisations           NUMERIC(19, 2) NOT NULL DEFAULT 0,
    total_creances_compensees   NUMERIC(19, 2) NOT NULL DEFAULT 0,
    montant_net                 NUMERIC(19, 2) NOT NULL DEFAULT 0,
    reliquat_reporte            NUMERIC(19, 2) NOT NULL DEFAULT 0,
    mode_paiement               VARCHAR(30),
    compte_tresorerie_id        BIGINT,
    operation_decaissement_id   BIGINT,
    created_at                  TIMESTAMP,
    CONSTRAINT fk_reglements_arrete_arrete    FOREIGN KEY (arrete_id) REFERENCES arretes_compte(id),
    CONSTRAINT fk_reglements_arrete_chauffeur FOREIGN KEY (chauffeur_id) REFERENCES chauffeurs(id),
    CONSTRAINT fk_reglements_arrete_operation FOREIGN KEY (operation_decaissement_id) REFERENCES operations_financieres(id)
);

CREATE INDEX IF NOT EXISTS idx_reglements_arrete_arrete    ON reglements_arrete(arrete_id);
CREATE INDEX IF NOT EXISTS idx_reglements_arrete_chauffeur ON reglements_arrete(chauffeur_id);
