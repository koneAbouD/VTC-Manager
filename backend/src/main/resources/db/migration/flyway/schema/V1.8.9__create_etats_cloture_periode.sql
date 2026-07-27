-- États figés au moment de la clôture mensuelle.
--
-- Le compte de résultat et le bilan étaient recalculés à chaque consultation :
-- une donnée amont qui bouge (barème d'amortissement, catégorie reclassée,
-- créance soldée) faisait changer rétroactivement un mois pourtant clos. On
-- archive donc les états à la clôture, et c'est cette photo qui est servie pour
-- les périodes closes.
CREATE TABLE IF NOT EXISTS etats_cloture_periode (
    id                     BIGSERIAL      PRIMARY KEY,
    cloture_periode_id     BIGINT         NOT NULL,

    -- Compte de résultat, base caisse
    produits_caisse        NUMERIC(19, 2) NOT NULL,
    charges_variables      NUMERIC(19, 2) NOT NULL,
    charges_fixes          NUMERIC(19, 2) NOT NULL,
    amortissements         NUMERIC(19, 2) NOT NULL,
    resultat_caisse        NUMERIC(19, 2) NOT NULL,

    -- Compte de résultat, base engagement
    produits_engagement    NUMERIC(19, 2) NOT NULL,
    resultat_engagement    NUMERIC(19, 2) NOT NULL,
    pont_creances          NUMERIC(19, 2) NOT NULL,

    -- Bilan de gestion arrêté au dernier jour de la période
    tresorerie             NUMERIC(19, 2) NOT NULL,
    creances_chauffeurs    NUMERIC(19, 2) NOT NULL,
    immobilisations_nettes NUMERIC(19, 2) NOT NULL,
    total_actif            NUMERIC(19, 2) NOT NULL,
    dette_etat             NUMERIC(19, 2) NOT NULL,
    situation_nette        NUMERIC(19, 2) NOT NULL,

    created_at             TIMESTAMP,
    updated_at             TIMESTAMP,
    created_by             VARCHAR(255),
    updated_by             VARCHAR(255),
    CONSTRAINT uk_etats_cloture_periode UNIQUE (cloture_periode_id),
    CONSTRAINT fk_etats_cloture_periode FOREIGN KEY (cloture_periode_id)
        REFERENCES clotures_periode(id)
);

-- Détail des soldes de trésorerie compte par compte, arrêtés au dernier jour de
-- la période : c'est la pièce qui permet de justifier la ligne « trésorerie »
-- du bilan archivé.
CREATE TABLE IF NOT EXISTS soldes_cloture_periode (
    id                 BIGSERIAL      PRIMARY KEY,
    cloture_periode_id BIGINT         NOT NULL,
    compte_id          BIGINT         NOT NULL,
    libelle_compte     VARCHAR(255),
    solde              NUMERIC(19, 2) NOT NULL,
    CONSTRAINT uk_soldes_cloture_periode UNIQUE (cloture_periode_id, compte_id),
    CONSTRAINT fk_soldes_cloture_periode FOREIGN KEY (cloture_periode_id)
        REFERENCES clotures_periode(id),
    CONSTRAINT fk_soldes_cloture_compte FOREIGN KEY (compte_id)
        REFERENCES comptes_tresorerie(id)
);

CREATE INDEX IF NOT EXISTS idx_soldes_cloture_periode
    ON soldes_cloture_periode(cloture_periode_id);
