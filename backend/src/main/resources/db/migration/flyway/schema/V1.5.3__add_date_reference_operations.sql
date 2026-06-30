-- Date "métier" de référence d'une opération financière : pour un encaissement
-- de période, c'est la date de la période concernée (recette/cotisation/faute)
-- plutôt que la date de la transaction (date_operation). Sert à l'affichage.
ALTER TABLE operations_financieres ADD COLUMN date_reference DATE;
