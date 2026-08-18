-- Une maintenance rouverte repart PLANIFIEE, toujours.
--
-- L'annulation de la dépense issue d'une complétion restaurait le statut
-- mémorisé juste avant celle-ci (PLANIFIEE ou EN_COURS). L'intervention
-- annulée est pourtant à refaire depuis le début : elle doit se retrouver
-- dans les maintenances à planifier, pas dans celles en cours d'exécution.
-- Le statut d'avant complétion n'a donc plus d'emploi.
ALTER TABLE maintenances DROP COLUMN IF EXISTS statut_avant_completion;
