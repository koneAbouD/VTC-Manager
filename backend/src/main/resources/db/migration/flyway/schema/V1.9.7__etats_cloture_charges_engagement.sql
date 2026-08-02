-- Charges base engagement dans la photo de clôture.
--
-- La clôture n'archivait que les charges base CAISSE. Relire un mois clos en
-- base ENGAGEMENT reconstruisait donc la cascade en croisant les produits
-- engagement avec les charges caisse : dès qu'une facture partenaire était
-- reçue et non réglée dans le mois, le résultat servi divergeait du
-- resultat_engagement pourtant archivé à la clôture. Le mois publié se
-- contredisait lui-même.
--
-- Les colonnes sont NULLABLES à dessein : NULL veut dire « cette photo est
-- antérieure et n'a pas la donnée » (le code retombe alors sur les colonnes
-- caisse, comme avant), là où 0 voudrait dire « aucune charge engagée ce
-- mois-là » — ce qui serait faux.
ALTER TABLE etats_cloture_periode
    ADD COLUMN IF NOT EXISTS charges_variables_engagement NUMERIC(19, 2),
    ADD COLUMN IF NOT EXISTS charges_fixes_engagement NUMERIC(19, 2);

-- Les photos déjà archivées ne sont pas retouchées : un état publié ne se
-- réécrit pas. Seules les clôtures à venir porteront les deux jeux de charges.
