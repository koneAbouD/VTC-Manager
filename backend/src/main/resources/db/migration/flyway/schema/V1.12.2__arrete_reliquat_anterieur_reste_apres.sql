-- Arrêté de compte : ce qu'il faut pour un décompte lisible d'une période à l'autre.
--
-- reglements_arrete.reliquat_anterieur : ce que le chauffeur devait encore, au
-- moment de l'arrêté, sur ses créances antérieures au début de la période — le
-- reliquat reporté des périodes précédentes, repris en tête du décompte.
--
-- lignes_arrete.reste_apres : ce qui reste dû sur la créance une fois la part
-- de cet arrêté imputée. Figé à la création : les paiements ultérieurs ne
-- doivent pas réécrire ce que le décompte disait. Nul pour les cotisations et
-- pour les arrêtés antérieurs à cette migration (inconnu).
ALTER TABLE reglements_arrete
    ADD COLUMN reliquat_anterieur NUMERIC(19, 2) NOT NULL DEFAULT 0;

ALTER TABLE lignes_arrete
    ADD COLUMN reste_apres NUMERIC(19, 2);
