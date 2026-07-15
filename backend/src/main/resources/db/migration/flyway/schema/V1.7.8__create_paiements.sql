-- V2 app chauffeur : paiements Mobile Money des recettes / cotisations.
-- Machine à états découplée de l'encaissement métier ; le webhook agrégateur
-- (ou le polling) fait foi. `reference` = clé d'idempotence de l'initiation ;
-- `encaissement_id` garantit l'idempotence de la création de l'encaissement.

CREATE TABLE paiements (
    id                BIGSERIAL PRIMARY KEY,
    reference         VARCHAR(40)  NOT NULL UNIQUE,
    type_cible        VARCHAR(20)  NOT NULL,           -- RECETTE | COTISATION
    cible_id          BIGINT       NOT NULL,           -- ligne recette / cotisation
    chauffeur_id      BIGINT       NOT NULL,
    vehicule_id       BIGINT,
    montant           NUMERIC(14,2) NOT NULL,
    canal             VARCHAR(20)  NOT NULL,           -- WAVE | ORANGE_MONEY | MTN_MOMO | MOOV_MONEY
    telephone         VARCHAR(30)  NOT NULL,
    statut            VARCHAR(20)  NOT NULL,           -- INITIE | EN_ATTENTE | REUSSI | ECHOUE | EXPIRE
    gateway_reference VARCHAR(100),
    payment_url       TEXT,
    encaissement_id   BIGINT,
    message_erreur    TEXT,
    created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_paiements_chauffeur ON paiements (chauffeur_id);
CREATE INDEX ix_paiements_gateway_reference ON paiements (gateway_reference);
