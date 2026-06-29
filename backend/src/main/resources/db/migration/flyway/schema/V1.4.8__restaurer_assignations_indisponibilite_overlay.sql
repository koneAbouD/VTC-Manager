-- Passage du modèle de remplacement "FK-swap permanent" au modèle "overlay par date".
--
-- L'ancien code remplaçait définitivement le chauffeur titulaire par son
-- remplaçant dans vehicule_programme_chauffeurs (avec un suivi dans
-- indisponibilite_remplacements). Le nouveau modèle ne mute plus le programme :
-- la substitution est calculée par date, uniquement sur la période de l'indispo.
--
-- Cette migration rétablit donc les assignations échangées restées en base, puis
-- purge le suivi devenu inutile. Sans elle, les remplaçants déjà appliqués
-- continueraient d'apparaître hors période.

UPDATE vehicule_programme_chauffeurs pc
SET chauffeur_id = ir.chauffeur_titulaire_id
FROM indisponibilite_remplacements ir
WHERE pc.id = ir.programme_chauffeur_id;

DELETE FROM indisponibilite_remplacements;
