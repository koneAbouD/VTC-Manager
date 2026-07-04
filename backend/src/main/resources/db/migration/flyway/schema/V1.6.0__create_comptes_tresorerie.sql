CREATE TABLE IF NOT EXISTS comptes_tresorerie (
    id            BIGSERIAL      PRIMARY KEY,
    code          VARCHAR(50)    NOT NULL,
    libelle       VARCHAR(100)   NOT NULL,
    type          VARCHAR(20)    NOT NULL,
    operateur     VARCHAR(30),
    solde_initial NUMERIC(19, 2) NOT NULL DEFAULT 0,
    par_defaut    BOOLEAN        NOT NULL DEFAULT FALSE,
    actif         BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP,
    CONSTRAINT uk_comptes_tresorerie_code UNIQUE (code),
    CONSTRAINT chk_comptes_tresorerie_type CHECK (type IN ('CAISSE', 'MOBILE_MONEY', 'BANQUE'))
);

-- Un seul compte par défaut par type : c'est lui qui reçoit les opérations
-- dont le compte n'est pas précisé (résolution via le mode de paiement).
CREATE UNIQUE INDEX IF NOT EXISTS uk_comptes_tresorerie_defaut_type
    ON comptes_tresorerie (type) WHERE par_defaut;

-- Comptes de démarrage : nécessaires au backfill des opérations existantes
-- (V1.6.1) et à la résolution par défaut côté use cases.
INSERT INTO comptes_tresorerie (code, libelle, type, par_defaut, actif) VALUES
    ('CAISSE_PRINCIPALE', 'Caisse espèces', 'CAISSE',       TRUE, TRUE),
    ('MOMO_PRINCIPAL',    'Mobile money',   'MOBILE_MONEY', TRUE, TRUE)
ON CONFLICT (code) DO NOTHING;
