-- Retire le suffixe « - Prestataire non renseigné » des libellés de maintenance.
--
-- Terminer une intervention fabrique un libellé « Maintenance <TYPE> - <partenaire> ».
-- Sans partenaire, la place était comblée par « Prestataire non renseigné », qui
-- n'apporte aucune information et occupe le titre des lignes dans le rapport
-- financier. La génération s'arrête désormais au type (CompleteMaintenanceUseCase
-- et SynchronisationDetteMaintenanceService) ; il reste à corriger l'existant.
--
-- Deux colonnes portent ce libellé : le commentaire de la dépense payée comptant
-- et la description de la dette quand l'intervention est prise à crédit.
-- L'ancrage `$` limite le retrait au suffixe : un commentaire saisi à la main qui
-- contiendrait cette phrase ailleurs n'est pas touché.

UPDATE operations_financieres
SET commentaire = regexp_replace(commentaire, ' - Prestataire non renseigné$', '')
WHERE commentaire LIKE '% - Prestataire non renseigné';

UPDATE factures_partenaire
SET description = regexp_replace(description, ' - Prestataire non renseigné$', '')
WHERE description LIKE '% - Prestataire non renseigné';
