-- Dépôts de cotisation au passif de la photo de clôture.
--
-- Les cotisations sont un dépôt détenu pour le compte du chauffeur, restitué en
-- fin de période — c'est d'ailleurs pourquoi elles ont été reclassées
-- HORS_RESULTAT. Leur encaissement entrait pourtant dans la trésorerie à l'actif
-- sans contrepartie au passif : la situation nette absorbait un argent qui ne
-- reste pas à l'entreprise.
--
-- Le montant est porté BRUT, sans compensation avec les créances du même
-- chauffeur : la dette de restitution et la créance de recette sont deux postes
-- distincts, les compenser les ferait disparaître tous les deux.
ALTER TABLE etats_cloture_periode
    ADD COLUMN IF NOT EXISTS depots_cotisations NUMERIC(19, 2) NOT NULL DEFAULT 0;

-- Les photos déjà archivées ne sont pas retouchées : un état publié ne se
-- réécrit pas. Elles restent à 0, et leur situation nette reste celle qui a été
-- publiée. Seules les clôtures à venir porteront la dette.
