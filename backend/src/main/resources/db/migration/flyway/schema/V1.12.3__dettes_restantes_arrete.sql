-- Dettes restant dues à la fin d'un arrêté : chaque créance datée jusqu'à la fin
-- de la période que l'arrêté laisse ouverte, avec ce qu'elle doit encore.
-- Le détail du « reste dû reporté », qui n'était jusque-là qu'un total.
--
-- Table à part, et non des lignes DEBIT à zéro dans lignes_arrete : une ligne
-- d'arrêté vaut compensation — elle se contre-passe à l'annulation et fige le
-- débiteur du document (réaffectation refusée). Une dette simplement constatée
-- ne doit rien de tout cela.
CREATE TABLE IF NOT EXISTS dettes_restantes_arrete (
    id             BIGSERIAL      PRIMARY KEY,
    arrete_id      BIGINT         NOT NULL,
    document_type  VARCHAR(20)    NOT NULL,            -- RECETTE | PENALITE | CONTRAVENTION
    document_id    BIGINT         NOT NULL,
    chauffeur_id   BIGINT,                             -- null : dette du véhicule
    vehicule_id    BIGINT,
    montant_du     NUMERIC(19, 2),                     -- ce que le document réclamait
    reste          NUMERIC(19, 2) NOT NULL,            -- ce qu'il doit encore après l'arrêté
    created_at     TIMESTAMP,
    CONSTRAINT fk_dettes_restantes_arrete_arrete FOREIGN KEY (arrete_id) REFERENCES arretes_compte(id)
);

CREATE INDEX IF NOT EXISTS idx_dettes_restantes_arrete_arrete ON dettes_restantes_arrete(arrete_id);
