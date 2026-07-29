-- Dettes fournisseurs : achats à crédit et échéancier.
--
-- Jusqu'ici, une charge n'existait qu'au moment où elle était payée : une
-- facture de garage reçue en mars et réglée en avril tombait sur avril. Le
-- résultat mensuel était donc faux des deux côtés, et rien ne disait ce que
-- l'entreprise devait à ses fournisseurs.
--
-- La facture porte désormais la charge, à sa date ; le règlement n'est plus
-- qu'un mouvement de trésorerie qui solde la dette.

CREATE TABLE IF NOT EXISTS fournisseurs (
    id           BIGSERIAL    PRIMARY KEY,
    nom          VARCHAR(150) NOT NULL,
    type         VARCHAR(20)  NOT NULL,
    telephone    VARCHAR(30),
    email        VARCHAR(150),
    adresse      VARCHAR(255),
    -- Compte contribuable : utile au cabinet pour justifier la charge.
    numero_compte_contribuable VARCHAR(50),
    commentaire  TEXT,
    actif        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP,
    created_by   VARCHAR(255),
    updated_by   VARCHAR(255),
    CONSTRAINT uk_fournisseurs_nom UNIQUE (nom),
    CONSTRAINT chk_fournisseurs_type CHECK (type IN
        ('GARAGE', 'PIECES', 'CARBURANT', 'ASSURANCE', 'ADMINISTRATION', 'BAILLEUR', 'AUTRE'))
);

CREATE INDEX IF NOT EXISTS idx_fournisseurs_actif ON fournisseurs(actif);

CREATE TABLE IF NOT EXISTS factures_fournisseur (
    id              BIGSERIAL      PRIMARY KEY,
    reference       VARCHAR(30)    NOT NULL,
    fournisseur_id  BIGINT         NOT NULL,
    -- Numéro porté par la pièce du fournisseur, tel qu'il figure dessus.
    numero_piece    VARCHAR(100),
    categorie_id    BIGINT,
    vehicule_id     BIGINT,
    -- Date de la facture : c'est elle qui date la charge.
    date_facture    DATE           NOT NULL,
    -- Échéance convenue ; à défaut, la date de facture.
    date_echeance   DATE           NOT NULL,
    montant         NUMERIC(19, 2) NOT NULL,
    montant_paye    NUMERIC(19, 2) NOT NULL DEFAULT 0,
    statut          VARCHAR(25)    NOT NULL,
    description     TEXT,
    motif_annulation TEXT,
    annule_le       TIMESTAMP,
    annule_par      VARCHAR(255),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    created_by      VARCHAR(255),
    updated_by      VARCHAR(255),
    CONSTRAINT uk_factures_fournisseur_reference UNIQUE (reference),
    CONSTRAINT fk_factures_fournisseur_tiers     FOREIGN KEY (fournisseur_id) REFERENCES fournisseurs(id),
    CONSTRAINT fk_factures_fournisseur_categorie FOREIGN KEY (categorie_id)   REFERENCES categories_operation(id),
    CONSTRAINT fk_factures_fournisseur_vehicule  FOREIGN KEY (vehicule_id)    REFERENCES vehicules(id),
    CONSTRAINT chk_factures_fournisseur_montant  CHECK (montant > 0),
    CONSTRAINT chk_factures_fournisseur_paye     CHECK (montant_paye >= 0),
    CONSTRAINT chk_factures_fournisseur_statut   CHECK (statut IN
        ('A_PAYER', 'PARTIELLEMENT_PAYEE', 'PAYEE', 'ANNULEE'))
);

CREATE INDEX IF NOT EXISTS idx_factures_fournisseur_tiers    ON factures_fournisseur(fournisseur_id);
CREATE INDEX IF NOT EXISTS idx_factures_fournisseur_date     ON factures_fournisseur(date_facture);
CREATE INDEX IF NOT EXISTS idx_factures_fournisseur_echeance ON factures_fournisseur(date_echeance);
-- Les factures ouvertes portent la dette : elles sont lues à chaque bilan.
CREATE INDEX IF NOT EXISTS idx_factures_fournisseur_ouvertes
    ON factures_fournisseur(date_echeance)
    WHERE statut IN ('A_PAYER', 'PARTIELLEMENT_PAYEE');

-- Lien règlement → facture. C'est lui qui évite le double comptage : une charge
-- déjà portée par une facture ne doit pas être comptée une seconde fois par son
-- règlement dans la lecture en base engagement.
ALTER TABLE operations_financieres
    ADD COLUMN IF NOT EXISTS facture_fournisseur_id BIGINT;
ALTER TABLE operations_financieres
    DROP CONSTRAINT IF EXISTS fk_operations_financieres_facture;
ALTER TABLE operations_financieres
    ADD CONSTRAINT fk_operations_financieres_facture
    FOREIGN KEY (facture_fournisseur_id) REFERENCES factures_fournisseur(id);
CREATE INDEX IF NOT EXISTS idx_operations_financieres_facture
    ON operations_financieres(facture_fournisseur_id)
    WHERE facture_fournisseur_id IS NOT NULL;

-- Le bilan archivé gagne son poste de passif.
ALTER TABLE etats_cloture_periode
    ADD COLUMN IF NOT EXISTS dettes_fournisseurs NUMERIC(19, 2) NOT NULL DEFAULT 0;
